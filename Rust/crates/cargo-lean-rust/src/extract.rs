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

/// The `rs:` extern of `f`, with the Rust types `types` of the type parameters of a generic
/// function.
pub fn rust_extern(items: &CrateItems, f: &ModelFn, types: &[String]) -> String {
    let (s, t) = rust_paths(items, f);
    gen::rust_extern(f, s.as_deref(), t.as_deref(), types)
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

/// The spec in an obligation: a generated function by its name from the root, which the
/// namespaces the obligation module opens cannot capture.
fn to_spec(r: &Resolved) -> Spec {
    Spec {
        lean: if r.boolean {
            format!("_root_.{}", r.lean)
        } else {
            r.lean.clone()
        },
        boolean: r.boolean,
        named: Vec::new(),
    }
}

/// One obligation of a label: for a generic function, the one for every type (`generic`) or
/// the one of a type of `instances` (`per_instance`, with the suffix `.<type>`).
pub struct Case {
    pub suffix: String,
    pub parts: gen::GenericParts,
    pub spec: Spec,
    pub requires: Option<Spec>,
}

/// The spec `r` for the Rust types `types` of a polymorphic spec: its instantiation.
pub fn instance_spec(r: &Resolved, types: &[String], at: &str) -> Result<Spec, String> {
    let mut s = to_spec(r);
    if r.instances.is_empty() || !r.boolean {
        return Ok(s);
    }
    let key = if types.len() == 1 {
        types[0].clone()
    } else {
        format!("({})", types.join(","))
    };
    let key = lean_rust_build::model::normalize_type(&key);
    match r
        .instances
        .iter()
        .find(|(t, _)| lean_rust_build::model::normalize_type(t) == key)
    {
        Some((_, lean)) => {
            s.lean = format!("_root_.{lean}");
            Ok(s)
        }
        None => Err(format!(
            "{at}: the spec {} is not instantiated for `{key}`: add it to its `rust_instances`",
            r.lean
        )),
    }
}

/// The polymorphic spec `r` applied to the type parameters `params` of the model.
fn generic_spec(r: &Resolved, params: &[String]) -> Spec {
    let mut s = to_spec(r);
    if r.boolean && !r.type_params.is_empty() && r.type_params.len() == params.len() {
        s.named = r
            .type_params
            .iter()
            .zip(params)
            .map(|(a, t)| format!("({a} := {t})"))
            .collect();
    }
    s
}

/// The obligations of `f` for the spec `r`.
pub fn cases(
    f: &ModelFn,
    binders: &[gen::Binder],
    requires: Option<&Resolved>,
    r: &Resolved,
    instances_of_crate: &dyn Fn(&str, &str) -> Option<String>,
) -> Result<Vec<Case>, String> {
    let at = format!("{}:{}", f.file, f.line);
    if f.sig.generics.is_empty() {
        return Ok(vec![Case {
            suffix: String::new(),
            parts: gen::GenericParts::default(),
            spec: to_spec(r),
            requires: requires.map(to_spec),
        }]);
    }
    let params: Vec<String> = binders
        .iter()
        .filter(|b| b.implicit && b.ty.starts_with("Type"))
        .map(|b| b.name.clone())
        .collect();
    if params.len() != f.sig.generics.len() {
        return Err(format!(
            "{at}: the model of {} has {} type parameters, the Rust function {}",
            f.rust,
            params.len(),
            f.sig.generics.len()
        ));
    }
    if !f.attr.per_instance() {
        let parts = gen::generic_parts(binders, &gen::lean_params(f))
            .map_err(|e| format!("{at}: {}: {e}", f.rust))?;
        return Ok(vec![Case {
            suffix: String::new(),
            parts,
            spec: generic_spec(r, &params),
            requires: requires.map(|q| generic_spec(q, &params)),
        }]);
    }
    let mut out = Vec::new();
    for inst in &f.attr.instances {
        let types = instance_types(f, inst);
        if types.len() != params.len() {
            return Err(format!(
                "{at}: an instance of {} needs {} types",
                f.rust,
                params.len()
            ));
        }
        let mut insts = Vec::new();
        let values = gen::lean_params(f);
        for b in binders
            .iter()
            .filter(|b| !b.implicit && !values.contains(&b.name))
        {
            let mut words = b.ty.split_whitespace();
            let (Some(head), Some(first)) = (words.next(), words.next()) else {
                continue;
            };
            let Some(i) = params.iter().position(|p| p == first) else {
                continue;
            };
            let rust = &types[i];
            let name = gen::library_instance(head, rust)
                .or_else(|| instances_of_crate(head, rust))
                .ok_or_else(|| {
                    format!(
                        "{at}: no instance of `{head}` for `{rust}` in Aeneas's library or the crate's model"
                    )
                })?;
            insts.push(name);
        }
        out.push(Case {
            suffix: format!(".{}", lean_rust_build::model::instance_name(inst)),
            parts: gen::GenericParts {
                binders: String::new(),
                insts,
            },
            spec: instance_spec(r, &types, &at)?,
            requires: requires
                .map(|q| instance_spec(q, &types, &at))
                .transpose()?,
        });
    }
    Ok(out)
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
    let lean_dir = c.lean_dir();
    if items.models.is_empty() && items.opaque.is_empty() {
        return Err("the crate has no #[lean_rust::model] or #[lean_rust::opaque] function".into());
    }
    let untyped: Vec<String> = items
        .models
        .iter()
        .filter(|f| !f.sig.generics.is_empty() && f.attr.instances.is_empty())
        .map(|f| {
            format!(
                "{}:{}: {} is generic: give the types of its tests with `instances = [..]`",
                f.file, f.line, f.rust
            )
        })
        .collect();
    if !untyped.is_empty() {
        return Err(untyped.join("\n"));
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
        let (start, opaque) = match &o.self_path {
            Some(t) => {
                let mut segs = resolve(&items, &o.module, t);
                segs.push(o.name.clone());
                let start = charon_path(&ident, &segs);
                let mut glob = o.module.clone();
                glob.extend(["_".to_string(), o.name.clone()]);
                let module_prefix = std::iter::once("crate")
                    .chain(o.module.iter().map(String::as_str))
                    .map(|s| format!("{s}::"))
                    .collect::<String>();
                let clashes: Vec<&String> = items
                    .hashes
                    .keys()
                    .filter(|u| *u != &o.unit)
                    .filter(|u| {
                        u.strip_prefix(&module_prefix).is_some_and(|rest| {
                            rest.split_once("::")
                                .is_some_and(|(owner, name)| !owner.is_empty() && name == o.name)
                        })
                    })
                    .collect();
                if !clashes.is_empty() {
                    return Err(format!(
                        "{}: #[lean_rust::opaque] method {}: Charon matches the method of an impl block by its module and name only, and {} has the same: rename one",
                        o.file,
                        o.unit,
                        clashes.iter().map(|c| c.as_str()).collect::<Vec<_>>().join(", ")
                    ));
                }
                (start, charon_path(&ident, &glob))
            }
            None => {
                let mut segs = o.module.clone();
                segs.push(o.name.clone());
                let p = charon_path(&ident, &segs);
                (p.clone(), p)
            }
        };
        charon.arg("--start-from").arg(start);
        charon.arg("--opaque").arg(opaque);
    }
    charon.env("LEAN_RUST_EXTRACTING", "1").current_dir(&c.dir);
    println!(
        "charon cargo --preset=aeneas ({} functions, {} opaque)",
        items.models.len(),
        items.opaque.len()
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

    let mut errors = Vec::new();
    let mut aliases: BTreeMap<Vec<String>, String> = BTreeMap::new();
    let mut externs: BTreeMap<Vec<String>, String> = BTreeMap::new();
    let mut models: BTreeMap<String, Model> = BTreeMap::new();
    let mut binders: BTreeMap<String, Vec<gen::Binder>> = BTreeMap::new();
    for f in &items.models {
        let unit_of = |d: &AeneasDecl| d.rust.as_deref().and_then(|r| gen::aeneas_unit(r, &ident));
        let decl = decls
            .iter()
            .find(|d| d.loop_index.is_none() && unit_of(d).as_deref() == Some(f.rust.as_str()));
        let Some(decl) = decl else {
            let opaque = externals
                .iter()
                .any(|d| unit_of(d).as_deref() == Some(f.rust.as_str()));
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
        let mut model = Model {
            rust: f.rust.clone(),
            lean: lean.clone(),
            instances: f
                .attr
                .instances
                .iter()
                .map(lean_rust_build::model::type_text)
                .collect(),
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
        if f.sig.generics.is_empty() {
            let ext = externs.entry(f.module.clone()).or_default();
            let _ = writeln!(
                ext,
                "@[extern \"{}\"]\ndef {lean}.rs : type_of% @{lean} := @{lean}\n",
                rust_extern(&items, f, &[])
            );
        }
        binders.insert(f.rust.clone(), gen::decl_binders(&decl.body));
        models.insert(f.rust.clone(), model);
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
    for (module, text) in &externs {
        let m = module_of("Extern", &ident, module);
        write(
            &lean_dir.join(gen::module_path(&m)),
            &format!("{LEAN_HEADER}import {funs}\n{open}\n{text}"),
            &mut written,
        )?;
    }
    for d in ["Alias", "Extern"] {
        prune(&lean_dir.join("LeanRustGen").join(d).join(&ident), &written)?;
    }

    let (blocks, _) = b.scan().map_err(|e| e.to_string())?;
    b.generate_cache(&blocks, |_| true)
        .map_err(|e| e.to_string())?;
    let specs = Specs::new(c)?;
    let resolved = resolve_all(c, &items, &specs)?;
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

    let old = Lock::read(&b.lock_path())?;
    let mut lock = Lock {
        version: LOCK_VERSION,
        aeneas: AENEAS_REV.to_string(),
        charon: charon_version,
        model: Vec::new(),
    };
    let funs_text = read("Funs.lean");
    let crate_instance = |head: &str, rust: &str| {
        gen::crate_instance(&funs_text, head, rust).map(|n| format!("{ident}.{n}"))
    };
    let mut obligations: BTreeMap<Vec<String>, (BTreeSet<String>, String)> = BTreeMap::new();
    let mut uses_laws = false;
    for (f, requires, obls) in &resolved {
        let Some(mut model) = models.remove(&f.rust) else {
            continue;
        };
        let lean = model.lean.clone();
        let entry = obligations.entry(f.module.clone()).or_default();
        if let Some(i) = requires.as_ref().and_then(|r| r.import.as_ref()) {
            entry.0.insert(i.clone());
        }
        let model_binders = binders.get(&f.rust).cloned().unwrap_or_default();
        for (base, r) in obls {
            if let Some(i) = &r.import {
                entry.0.insert(i.clone());
            }
            for case in cases(f, &model_binders, requires.as_ref(), r, &crate_instance)? {
                if !case.parts.binders.is_empty() {
                    uses_laws = true;
                }
                let label = format!("{base}{}", case.suffix);
                let stmt = gen::obligation_statement(
                    f,
                    &lean,
                    &label,
                    &case.spec,
                    case.requires.as_ref(),
                    &case.parts,
                );
                let lean_label: Vec<String> = label.split('.').map(gen::lean_ident).collect();
                let _ = writeln!(
                    entry.1,
                    "/-- `{label}` of `{}`. -/\ndef {lean}.obligation.{} : Prop :=\n  {stmt}\n",
                    f.rust,
                    lean_label.join(".")
                );
                let h = hash(&format!("{stmt}\n{}", r.key));
                let previous = old.model(&f.rust).and_then(|m| {
                    m.obligation
                        .iter()
                        .find(|o| o.label == label && o.hash == h)
                });
                model.obligation.push(Obligation {
                    label: label.clone(),
                    spec: case.spec.lean.trim_start_matches("_root_.").to_string(),
                    spec_block: r.block.clone(),
                    spec_hash: r.key.clone(),
                    hash: h,
                    status: previous
                        .map(|o| o.status.clone())
                        .unwrap_or("unchecked".into()),
                    axioms: previous.map(|o| o.axioms.clone()).unwrap_or_default(),
                    proof: previous.map(|o| o.proof.clone()).unwrap_or_default(),
                });
            }
        }
        lock.model.push(model);
    }
    let laws = lean_dir.join(gen::module_path(gen::AENEAS_MODEL_MODULE));
    if uses_laws {
        write(&laws, lean_rust_build::AENEAS_MODEL_LEAN, &mut written)?;
    } else if laws.is_file() {
        fs::remove_file(&laws).map_err(|e| e.to_string())?;
    }

    for (module, (imports, text)) in &obligations {
        let m = module_of("Obligation", &ident, module);
        let mut head = format!("{LEAN_HEADER}import {funs}\n");
        if aliases.get(module).is_some_and(|t| !t.is_empty()) {
            let _ = writeln!(head, "import {}", module_of("Alias", &ident, module));
        }
        if uses_laws {
            let _ = writeln!(head, "import {}", gen::AENEAS_MODEL_MODULE);
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
    prune(
        &lean_dir.join("LeanRustGen").join("Obligation").join(&ident),
        &written,
    )?;
    fs::write(b.lock_path(), lock.to_toml()).map_err(|e| e.to_string())?;
    let n: usize = lock.model.iter().map(|m| m.obligation.len()).sum();
    println!(
        "extracted {} functions, {n} obligations: lean/LeanRustGen/{{Model,Alias,Obligation,Extern}}/, lean-rust.lock",
        lock.model.len()
    );
    Ok(())
}

/// The Rust types of the type parameters of `f` in the instance `inst`.
pub fn instance_types(f: &ModelFn, inst: &syn::Type) -> Vec<String> {
    match inst {
        syn::Type::Tuple(t) if f.sig.generics.len() != 1 => t
            .elems
            .iter()
            .map(lean_rust_build::model::type_text)
            .collect(),
        t => vec![lean_rust_build::model::type_text(t)],
    }
}

/// The trait structures of Aeneas for the Rust traits of the law classes.
fn trait_struct(rust: &str) -> Option<&'static str> {
    Some(match rust {
        "PartialEq" => "core.cmp.PartialEq",
        "Eq" => "core.cmp.Eq",
        "PartialOrd" => "core.cmp.PartialOrd",
        "Ord" => "core.cmp.Ord",
        "Clone" => "core.clone.Clone",
        "Copy" => "core.marker.Copy",
        "Default" => "core.default.Default",
        _ => return None,
    })
}

/// `true` when every bound of `f` holds for `types` by an instance of Aeneas's library that
/// lean-rs's `AeneasModel` proves to be a model: a generic proof applies to these types.
pub fn modelled_by_library(f: &ModelFn, types: &[String]) -> bool {
    f.sig.generics.iter().zip(types).all(|(p, t)| {
        p.bounds.iter().all(|b| {
            trait_struct(b).is_some_and(|s| lean_rust_build::gen::library_instance(s, t).is_some())
        })
    })
}
