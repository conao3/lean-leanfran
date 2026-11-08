//! `cargo lean-rust extract`.

use crate::{check_package, run, tool, Crate, Resolved, Specs, STUB};
use lean_rust_build::gen::{self, AeneasDecl, Spec, LEAN_HEADER};
use lean_rust_build::lock::{Lock, LockItem, Model, Obligation, LOCK_VERSION};
use lean_rust_build::model::{CrateItems, ModelFn};
use lean_rust_build::{AENEAS_REV, CHARON_VERSION};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn charon_path(crate_ident: &str, segs: &[String]) -> String {
    let mut s = crate_ident.to_string();
    for p in segs {
        s.push_str("::");
        s.push_str(p);
    }
    s
}

/// The absolute module path of a type or trait path written in `module`.
fn resolve(items: &CrateItems, module: &[String], segs: &[String]) -> Vec<String> {
    items.resolve_segments(module, segs, 0)
}

/// The Charon pattern of a modelled function (`--start-from`).
fn start_from(crate_ident: &str, items: &CrateItems, f: &ModelFn) -> String {
    let mut fn_path = f.module.clone();
    match (&f.self_path, &f.trait_path) {
        (Some(t), Some(tr)) => {
            let t = charon_path(crate_ident, &resolve(items, &f.module, t));
            let tr = charon_path(crate_ident, &resolve(items, &f.module, tr));
            format!("{{impl {tr} for {t}}}::{}", f.name)
        }
        (Some(t), None) => {
            let mut p = resolve(items, &f.module, t);
            p.push(f.name.clone());
            charon_path(crate_ident, &p)
        }
        _ => {
            fn_path.push(f.name.clone());
            charon_path(crate_ident, &fn_path)
        }
    }
}

/// The Rust path of the type and the trait of a method, from the generated code.
fn rust_paths(items: &CrateItems, f: &ModelFn) -> (Option<String>, Option<String>) {
    let p = |segs: &Option<Vec<String>>| {
        segs.as_ref()
            .map(|s| lean_rust_build::module_path_string(&resolve(items, &f.module, s)))
    };
    (p(&f.self_path), p(&f.trait_path))
}

pub fn rust_extern(items: &CrateItems, f: &ModelFn) -> String {
    let (s, t) = rust_paths(items, f);
    gen::rust_extern(f, s.as_deref(), t.as_deref())
}

fn hash(text: &str) -> String {
    let d = Sha256::digest(text.as_bytes());
    let hex: String = d.iter().map(|b| format!("{b:02x}")).collect();
    format!("sha256:{hex}")
}

fn write(path: &Path, text: &str, written: &mut BTreeSet<PathBuf>) -> Result<(), String> {
    if let Some(d) = path.parent() {
        fs::create_dir_all(d).map_err(|e| e.to_string())?;
    }
    if fs::read_to_string(path).ok().as_deref() != Some(text) {
        fs::write(path, text).map_err(|e| format!("{}: {e}", path.display()))?;
    }
    written.insert(path.to_path_buf());
    Ok(())
}

/// Removes the files below `dir` not in `live` and the empty directories.
pub fn prune(dir: &Path, live: &BTreeSet<PathBuf>) -> Result<(), String> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Ok(());
    };
    for e in entries.flatten() {
        let p = e.path();
        if p.is_dir() {
            prune(&p, live)?;
            if fs::read_dir(&p)
                .map_err(|e| e.to_string())?
                .next()
                .is_none()
            {
                fs::remove_dir(&p).map_err(|e| e.to_string())?;
            }
        } else if !live.contains(&p) {
            fs::remove_file(&p).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

/// A modelled function with its resolved `requires` and obligation specs.
pub type ResolvedFn<'a> = (&'a ModelFn, Option<Resolved>, Vec<(String, Resolved)>);

pub fn resolve_all<'a>(
    c: &Crate,
    items: &'a CrateItems,
    specs: &Specs,
) -> Result<Vec<ResolvedFn<'a>>, String> {
    let mut out = Vec::new();
    let mut errors = Vec::new();
    for f in &items.models {
        let requires = match &f.attr.requires {
            Some(r) => match specs.resolve(c, items, f, r) {
                Ok(r) => Some(r),
                Err(e) => {
                    errors.push(e);
                    None
                }
            },
            None => None,
        };
        let mut obls = Vec::new();
        for (label, spec) in f.attr.obligations() {
            match specs.resolve(c, items, f, spec) {
                Ok(r) => obls.push((label, r)),
                Err(e) => errors.push(e),
            }
        }
        out.push((f, requires, obls));
    }
    if errors.is_empty() {
        Ok(out)
    } else {
        Err(errors.join("\n"))
    }
}

fn to_spec(r: &Resolved) -> Spec {
    Spec {
        lean: r.lean.clone(),
        boolean: r.boolean,
    }
}

fn module_of(prefix: &str, ident: &str, module: &[String]) -> String {
    gen::module_of(prefix, ident, module)
}

pub fn extract(c: &Crate) -> Result<(), String> {
    check_package(c)?;
    let b = c.builder();
    let items = b.scan_items().map_err(|e| e.to_string())?;
    if !items.errors.is_empty() {
        return Err(items.errors.join("\n"));
    }
    let ident = c.ident();
    let specs = Specs::new(c)?;
    let resolved = resolve_all(c, &items, &specs)?;
    let lean_dir = c.lean_dir();
    if items.models.is_empty() {
        return Err("the crate has no #[lean_rust::model] function".into());
    }

    let llbc_dir = c.target_dir.join("lean-rust");
    fs::create_dir_all(&llbc_dir).map_err(|e| e.to_string())?;
    let llbc = llbc_dir.join(format!("{ident}.llbc"));
    let mut charon = Command::new(tool("CHARON", "charon"));
    charon
        .args(["cargo", "--preset=aeneas"])
        .arg(format!("--dest-file={}", llbc.display()));
    for f in &items.models {
        charon
            .arg("--start-from")
            .arg(start_from(&ident, &items, f));
    }
    for o in &items.opaque {
        let segs: Vec<String> = o
            .trim_start_matches("crate::")
            .split("::")
            .map(str::to_string)
            .collect();
        charon.arg("--opaque").arg(charon_path(&ident, &segs));
    }
    charon.env("LEAN_RUST_EXTRACTING", "1").current_dir(&c.dir);
    println!(
        "charon cargo --preset=aeneas ({} functions)",
        items.models.len()
    );
    run(&mut charon, "charon")?;
    let charon_version = run(
        Command::new(tool("CHARON", "charon")).arg("version"),
        "charon version",
    )?;
    let charon_version = charon_version
        .split_whitespace()
        .next()
        .unwrap_or("")
        .to_string();
    if charon_version != CHARON_VERSION {
        return Err(format!(
            "charon is {charon_version}; this lean-rust needs the Charon {CHARON_VERSION} of Aeneas {AENEAS_REV}"
        ));
    }

    let sub = format!("LeanRustGen/Model/{ident}");
    let model_dir = lean_dir.join(&sub);
    if model_dir.exists() {
        fs::remove_dir_all(&model_dir).map_err(|e| e.to_string())?;
    }
    println!("aeneas -backend lean");
    let out = run(
        Command::new(tool("AENEAS", "aeneas"))
            .args(["-backend", "lean"])
            .arg(&llbc)
            .arg("-dest")
            .arg(&lean_dir)
            .args([
                "-subdir",
                &sub,
                "-split-files",
                "-namespace",
                &ident,
                "-loops-to-rec",
            ]),
        "aeneas",
    )?;
    if out.contains("[Error]") {
        return Err(format!("aeneas reported errors:\n{out}"));
    }
    for (template, shim, user, import) in [
        (
            "FunsExternal_Template.lean",
            "FunsExternal.lean",
            "External.lean",
            "External",
        ),
        (
            "TypesExternal_Template.lean",
            "TypesExternal.lean",
            "ExternalTypes.lean",
            "ExternalTypes",
        ),
    ] {
        let t = model_dir.join(template);
        if !t.is_file() {
            continue;
        }
        fs::write(
            model_dir.join(shim),
            format!("{LEAN_HEADER}module\npublic import {import}\n"),
        )
        .map_err(|e| e.to_string())?;
        let u = lean_dir.join(user);
        let current = fs::read_to_string(&u).unwrap_or_default();
        if current.is_empty() || current == STUB {
            fs::copy(&t, &u).map_err(|e| e.to_string())?;
            println!("wrote lean/{user} from {sub}/{template}: replace its axioms by definitions");
        } else {
            println!("note: {sub}/{template} lists the declarations lean/{user} must define");
        }
    }

    let read = |f: &str| fs::read_to_string(model_dir.join(f)).unwrap_or_default();
    let mut decls: Vec<AeneasDecl> = gen::parse_aeneas(&read("Funs.lean"));
    decls.extend(gen::parse_aeneas(&read("Types.lean")));
    let externals: Vec<AeneasDecl> = gen::parse_aeneas(&read("FunsExternal_Template.lean"));

    let old = Lock::read(&b.lock_path())?;
    let mut lock = Lock {
        version: LOCK_VERSION,
        aeneas: AENEAS_REV.to_string(),
        charon: charon_version,
        model: Vec::new(),
    };
    let mut aliases: BTreeMap<Vec<String>, String> = BTreeMap::new();
    let mut obligations: BTreeMap<Vec<String>, (BTreeSet<String>, String)> = BTreeMap::new();
    let mut externs: BTreeMap<Vec<String>, String> = BTreeMap::new();
    let mut errors = Vec::new();
    let all_blocks: Vec<String> = specs
        .blocks
        .iter()
        .filter(|b| {
            !b.imports
                .iter()
                .any(|i| i.starts_with("LeanRustGen.Obligation") || i.starts_with("Proofs"))
        })
        .map(|b| b.lean_module(&ident))
        .collect();
    let block_namespaces: Vec<String> = specs
        .blocks
        .iter()
        .filter(|b| all_blocks.contains(&b.lean_module(&ident)))
        .map(|b| b.name.clone())
        .collect();

    for (f, requires, obls) in &resolved {
        let decl = decls.iter().find(|d| {
            d.loop_index.is_none()
                && d.rust
                    .as_deref()
                    .and_then(|r| gen::aeneas_unit(r, &ident))
                    .as_deref()
                    == Some(f.rust.as_str())
        });
        let Some(decl) = decl else {
            let opaque = externals.iter().any(|d| {
                d.rust
                    .as_deref()
                    .and_then(|r| gen::aeneas_unit(r, &ident))
                    .as_deref()
                    == Some(f.rust.as_str())
            });
            errors.push(if opaque {
                format!("{}:{}: {} is modelled and opaque", f.file, f.line, f.rust)
            } else {
                format!(
                    "{}:{}: Aeneas did not translate {} (see the output of charon and aeneas)",
                    f.file, f.line, f.rust
                )
            });
            continue;
        };
        let lean = format!("{ident}.{}", decl.lean);
        match gen::loop_aliases(f, &decls, &decl.lean) {
            Ok(list) => {
                let text = aliases.entry(f.module.clone()).or_default();
                for (labels, target) in list {
                    let labels: Vec<String> = labels.iter().map(|l| gen::lean_ident(l)).collect();
                    let _ = writeln!(
                        text,
                        "@[reducible] def {lean}.{} := @{ident}.{target}",
                        labels.join(".")
                    );
                }
            }
            Err(e) => errors.push(e),
        }
        let entry = obligations.entry(f.module.clone()).or_default();
        let mut model = Model {
            rust: f.rust.clone(),
            lean: lean.clone(),
            items: Vec::new(),
            obligation: Vec::new(),
        };
        let mut units = gen::reachable_units(&decls, &decl.lean, &ident);
        units.insert(f.rust.clone());
        let mut seen = BTreeSet::new();
        for u in units {
            let unit = if items.hashes.contains_key(&u) {
                u
            } else if let Some((module, rest)) = u.split_once("::<") {
                let ty = rest.split(" as ").next().unwrap_or("");
                format!("{module}::{ty}")
            } else {
                continue;
            };
            if let Some(h) = items.hashes.get(&unit) {
                if seen.insert(unit.clone()) {
                    model.items.push(LockItem {
                        rust: unit,
                        hash: h.clone(),
                    });
                }
            }
        }
        if let Some(r) = requires {
            if let Some(i) = &r.import {
                entry.0.insert(i.clone());
            }
        }
        for (label, r) in obls {
            if let Some(i) = &r.import {
                entry.0.insert(i.clone());
            }
            let stmt = gen::obligation_statement(
                f,
                &lean,
                label,
                &to_spec(r),
                requires.as_ref().map(to_spec).as_ref(),
            );
            let _ = writeln!(
                entry.1,
                "/-- `{label}` of `{}`. -/\ndef {lean}.obligation.{} : Prop :=\n  {stmt}\n",
                f.rust,
                gen::lean_ident(label)
            );
            let h = hash(&format!("{stmt}\n{}", r.key));
            let previous = old.model(&f.rust).and_then(|m| {
                m.obligation
                    .iter()
                    .find(|o| o.label == *label && o.hash == h)
            });
            model.obligation.push(Obligation {
                label: label.clone(),
                spec: r.lean.clone(),
                spec_block: r.block.clone(),
                spec_key: r.key.clone(),
                hash: h,
                status: previous
                    .map(|o| o.status.clone())
                    .unwrap_or("unchecked".into()),
                axioms: previous.map(|o| o.axioms.clone()).unwrap_or_default(),
                proof: previous.map(|o| o.proof.clone()).unwrap_or_default(),
            });
        }
        let ext = externs.entry(f.module.clone()).or_default();
        let _ = writeln!(
            ext,
            "@[extern \"{}\"]\ndef {lean}.rs : type_of% @{lean} := @{lean}\n",
            rust_extern(&items, f)
        );
        lock.model.push(model);
    }
    if !errors.is_empty() {
        return Err(errors.join("\n"));
    }

    let mut written = BTreeSet::new();
    let funs = gen::model_module(&ident);
    let open = "open Aeneas Aeneas.Std Result\n";
    for (module, text) in &aliases {
        if text.is_empty() {
            continue;
        }
        let m = module_of("Alias", &ident, module);
        write(
            &lean_dir.join(gen::module_path(&m)),
            &format!("{LEAN_HEADER}import {funs}\n{open}\n{text}"),
            &mut written,
        )?;
    }
    for (module, (imports, text)) in &obligations {
        let m = module_of("Obligation", &ident, module);
        let mut head = format!("{LEAN_HEADER}import {funs}\n");
        if aliases.get(module).is_some_and(|t| !t.is_empty()) {
            let _ = writeln!(head, "import {}", module_of("Alias", &ident, module));
        }
        let mut all: BTreeSet<String> = imports.clone();
        all.extend(all_blocks.iter().cloned());
        for i in &all {
            let _ = writeln!(head, "import {i}");
        }
        head.push_str(open);
        let mut ns = vec![ident.clone()];
        ns.extend(module.iter().map(|m| gen::lean_ident(m)));
        let _ = writeln!(head, "open {}", ns.join("."));
        if !block_namespaces.is_empty() {
            let _ = writeln!(head, "open {}", block_namespaces.join(" "));
        }
        write(
            &lean_dir.join(gen::module_path(&m)),
            &format!("{head}\n{text}"),
            &mut written,
        )?;
    }
    for (module, text) in &externs {
        let m = module_of("Extern", &ident, module);
        write(
            &lean_dir.join(gen::module_path(&m)),
            &format!("{LEAN_HEADER}import {funs}\n{open}\n{text}"),
            &mut written,
        )?;
    }
    for d in ["Alias", "Obligation", "Extern"] {
        prune(&lean_dir.join("LeanRustGen").join(d).join(&ident), &written)?;
    }
    fs::write(b.lock_path(), lock.to_toml()).map_err(|e| e.to_string())?;
    let n: usize = lock.model.iter().map(|m| m.obligation.len()).sum();
    println!(
        "extracted {} functions, {n} obligations: lean/LeanRustGen/{{Model,Alias,Obligation,Extern}}/, lean-rust.lock",
        lock.model.len()
    );
    Ok(())
}
