//! `cargo lean-rust check`.

use crate::extract::{resolve_all, rust_extern};
use crate::{check_package, current_states, run, tool, Crate, Specs};
use lean_rust_build::gen::{self, LEAN_HEADER};
use lean_rust_build::lock::Lock;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn lean_files(root: &Path, dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for e in entries.flatten() {
        let p = e.path();
        if p.is_dir() {
            lean_files(root, &p, out);
        } else if p.extension().is_some_and(|x| x == "lean") {
            out.push(p.strip_prefix(root).unwrap_or(&p).to_path_buf());
        }
    }
}

fn module_name(rel: &Path) -> String {
    let s = lean_rust_build::syntax::normalize_path(&rel.with_extension(""));
    s.replace('/', ".")
}

fn imports(text: &str) -> Vec<String> {
    text.lines()
        .filter_map(|l| {
            let l = l.trim_start();
            let l = l.strip_prefix("public ").unwrap_or(l);
            l.strip_prefix("import ").map(|m| m.trim().to_string())
        })
        .collect()
}

/// The files `lake build` reported errors in, relative to the package.
fn failed_files(log: &str, lean: &Path) -> BTreeSet<String> {
    let mut out = BTreeSet::new();
    let lean_abs = lean.canonicalize().unwrap_or(lean.to_path_buf());
    for line in log.lines() {
        let Some(rest) = line.strip_prefix("error: ") else {
            continue;
        };
        let Some(end) = rest.find(".lean:") else {
            continue;
        };
        let mut file = rest[..end + 5].to_string();
        if let Ok(p) = Path::new(&file).strip_prefix(&lean_abs) {
            file = lean_rust_build::syntax::normalize_path(p);
        }
        while let Some(f) = file.strip_prefix("./") {
            file = f.to_string();
        }
        out.insert(file);
    }
    out
}

pub fn check(c: &Crate) -> Result<(), String> {
    check_package(c)?;
    let b = c.builder();
    let lock_path = b.lock_path();
    let mut lock = Lock::read(&lock_path)?;
    if lock.model.is_empty() {
        return Err("lean-rust.lock has no models: run `cargo lean-rust extract`".into());
    }
    let states = current_states(c)?;
    let stale: Vec<String> = states
        .iter()
        .filter(|m| {
            m.obligations
                .iter()
                .any(|o| o.status == "stale" || o.status == "unextracted")
        })
        .map(|m| m.rust.clone())
        .collect();
    if !stale.is_empty() {
        return Err(format!(
            "the source changed since `cargo lean-rust extract` ({}): run it again",
            stale.join(", ")
        ));
    }
    let items = b.scan_items().map_err(|e| e.to_string())?;
    let specs = Specs::new(c)?;
    let resolved = resolve_all(c, &items, &specs)?;
    let lean = c.lean_dir();
    let lake = tool("LAKE", "lake");

    println!("lake build");
    let out = Command::new(&lake)
        .arg("build")
        .current_dir(&lean)
        .output()
        .map_err(|e| format!("cannot run lake: {e}"))?;
    let log = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    let failed = if out.status.success() {
        BTreeSet::new()
    } else {
        failed_files(&log, &lean)
    };
    if !out.status.success() && failed.is_empty() {
        return Err(format!("lake build failed:\n{log}"));
    }
    let generated: Vec<&String> = failed
        .iter()
        .filter(|f| !f.starts_with("Proofs/"))
        .collect();
    if !generated.is_empty() {
        let errors: Vec<&str> = log.lines().filter(|l| l.starts_with("error: ")).collect();
        return Err(format!(
            "lake build failed outside lean/Proofs/ ({}):\n{}",
            generated
                .iter()
                .map(|s| s.as_str())
                .collect::<Vec<_>>()
                .join(", "),
            errors.join("\n")
        ));
    }

    let mut proofs = Vec::new();
    lean_files(&lean, &lean.join("Proofs"), &mut proofs);
    let mut obligation_files = Vec::new();
    lean_files(
        &lean,
        &lean.join("LeanRustGen").join("Obligation"),
        &mut obligation_files,
    );
    let sources: BTreeMap<String, String> = proofs
        .iter()
        .map(|p| {
            (
                module_name(p),
                fs::read_to_string(lean.join(p)).unwrap_or_default(),
            )
        })
        .collect();
    let mut bad: BTreeSet<String> = failed.iter().map(|f| module_name(Path::new(f))).collect();
    loop {
        let more: Vec<String> = sources
            .iter()
            .filter(|(m, t)| !bad.contains(*m) && imports(t).iter().any(|i| bad.contains(i)))
            .map(|(m, _)| m.clone())
            .collect();
        if more.is_empty() {
            break;
        }
        bad.extend(more);
    }
    let mut modules: Vec<String> = obligation_files.iter().map(|p| module_name(p)).collect();
    modules.extend(sources.keys().filter(|m| !bad.contains(*m)).cloned());

    let query: Vec<serde_json::Value> = lock
        .model
        .iter()
        .flat_map(|m| {
            m.obligation
                .iter()
                .map(move |o| serde_json::json!({ "model": m.lean, "label": o.label }))
        })
        .collect();
    let tmp = c.target_dir.join("lean-rust");
    fs::create_dir_all(&tmp).map_err(|e| e.to_string())?;
    let qfile = tmp.join("obligations.json");
    fs::write(&qfile, serde_json::Value::Array(query).to_string()).map_err(|e| e.to_string())?;
    println!("lean-rust crate check");
    let result = run(
        Command::new(tool("LEAN_RUST_CLI", "lean-rust"))
            .args(["crate", "check", "--lake-dir"])
            .arg(&lean)
            .arg("--obligations")
            .arg(&qfile)
            .arg("--modules")
            .args(&modules),
        "lean-rust crate check",
    )?;
    let result: serde_json::Value =
        serde_json::from_str(&result).map_err(|e| format!("lean-rust crate check: {e}"))?;
    let result = result.as_array().cloned().unwrap_or_default();
    let get = |j: &serde_json::Value, k: &str| {
        j.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string()
    };
    for m in &mut lock.model {
        for o in &mut m.obligation {
            let Some(r) = result
                .iter()
                .find(|r| get(r, "model") == m.lean && get(r, "label") == o.label)
            else {
                continue;
            };
            let mut status = get(r, "status");
            o.axioms = r
                .get("axioms")
                .and_then(|a| a.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|x| x.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default();
            o.axioms.retain(|a| a != "sorryAx" || status != "sorry");
            let file = get(r, "file");
            o.proof = if file.is_empty() {
                String::new()
            } else {
                let line = r.get("line").and_then(|l| l.as_u64()).unwrap_or(0);
                format!("lean/{file}:{line}")
            };
            if status == "missing" {
                let short = o.theorem(&m.lean);
                let short = short.rsplitn(4, '.').collect::<Vec<_>>();
                let tail = short
                    .iter()
                    .take(3)
                    .rev()
                    .cloned()
                    .collect::<Vec<_>>()
                    .join(".");
                if let Some(f) = failed
                    .iter()
                    .find(|f| fs::read_to_string(lean.join(f)).is_ok_and(|t| t.contains(&tail)))
                {
                    status = "failed".to_string();
                    o.proof = format!("lean/{f}");
                }
            }
            o.status = status;
        }
    }

    let mut csimp = String::new();
    let mut csimp_imports = BTreeSet::new();
    let mut replaced = BTreeSet::new();
    for (f, requires, obls) in &resolved {
        let Some(m) = lock.model.iter().find(|m| m.rust == f.rust) else {
            continue;
        };
        if requires.is_some() {
            continue;
        }
        let Some((_, spec)) = obls.iter().find(|(l, _)| l == "refines") else {
            continue;
        };
        let proved = m
            .obligation
            .iter()
            .any(|o| o.label == "refines" && o.status == "proved");
        if !proved || !spec.boolean || !replaced.insert(spec.lean.clone()) {
            continue;
        }
        if let Some(i) = &spec.import {
            csimp_imports.insert(i.clone());
        }
        let lean_name = &m.lean;
        let _ = writeln!(
            csimp,
            "/-- `{}` runs the Rust function `{}`: `{lean_name}.proof.refines` proves that it computes the spec. -/\n\
             @[extern \"{}\"]\ndef {lean_name}.impl : type_of% @{s} := @{s}\n\n\
             @[csimp] theorem {lean_name}.csimp : @{s} = @{lean_name}.impl := rfl\n",
            spec.lean,
            f.rust,
            rust_extern(&items, f),
            s = spec.lean
        );
    }
    let csimp_path = b.csimp_path();
    if csimp.is_empty() {
        if csimp_path.exists() {
            fs::remove_file(&csimp_path).map_err(|e| e.to_string())?;
        }
    } else {
        let mut text = format!("{LEAN_HEADER}import {}\n", gen::model_module(&c.ident()));
        for i in &csimp_imports {
            let _ = writeln!(text, "import {i}");
        }
        text.push_str("open Aeneas Aeneas.Std Result\n\n");
        text.push_str(&csimp);
        if fs::read_to_string(&csimp_path).ok().as_deref() != Some(text.as_str()) {
            fs::write(&csimp_path, &text).map_err(|e| e.to_string())?;
        }
        run(
            Command::new(&lake)
                .args(["build", "LeanRustGen.Csimp"])
                .current_dir(&lean),
            "lake build LeanRustGen.Csimp",
        )?;
    }
    fs::write(&lock_path, lock.to_toml()).map_err(|e| e.to_string())?;
    print!("{}", lean_rust_build::verify::table(&current_states(c)?));
    Ok(())
}
