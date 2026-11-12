//! The state of the obligations of a crate, from its source and its lockfile, without Lean or
//! Charon: `stale` when an item a model was extracted from or a spec changed, `unextracted`
//! when a modelled function or an obligation is not in the lockfile, the state recorded by
//! `cargo lean-rust check` otherwise.

use crate::lock::Lock;
use crate::model::{CrateItems, ModelFn, SpecRef};
use std::collections::BTreeMap;
use std::fmt::Write;

#[derive(Debug, Clone, PartialEq)]
pub struct ObligationState {
    pub label: String,
    /// The spec as written in the attribute.
    pub spec: String,
    /// The Lean name of the spec, when extracted.
    pub spec_lean: String,
    pub status: String,
    pub axioms: Vec<String>,
    pub proof: String,
    /// `<model>.proof.<label>`, when extracted.
    pub theorem: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ModelState {
    pub rust: String,
    pub lean: String,
    pub file: String,
    pub doc_file: String,
    pub obligations: Vec<ObligationState>,
    /// The items whose hashes changed since the extraction.
    pub changed: Vec<String>,
}

/// The states of the modelled functions of `items`. `keys` are the current hashes of the specs
/// ([`crate::Builder::spec_hashes`]).
pub fn states(
    items: &CrateItems,
    lock: &Lock,
    keys: &BTreeMap<String, String>,
    crate_ident: &str,
) -> Vec<ModelState> {
    items
        .models
        .iter()
        .map(|f| model_state(f, items, lock, keys, crate_ident))
        .collect()
}

fn model_state(
    f: &ModelFn,
    items: &CrateItems,
    lock: &Lock,
    keys: &BTreeMap<String, String>,
    crate_ident: &str,
) -> ModelState {
    let entry = lock.model(&f.rust);
    let instances: Vec<String> = f
        .attr
        .instances
        .iter()
        .map(crate::model::type_text)
        .collect();
    let changed: Vec<String> = match entry {
        Some(m) => {
            let mut c: Vec<String> = m
                .items
                .iter()
                .filter(|i| items.hashes.get(&i.rust) != Some(&i.hash))
                .map(|i| i.rust.clone())
                .collect();
            if m.instances != instances {
                c.push(format!("instances of {}", f.rust));
            }
            c
        }
        None => Vec::new(),
    };
    let obligations = f
        .attr
        .obligation_labels()
        .into_iter()
        .map(|(label, spec, _)| {
            let spec_text = match spec {
                SpecRef::Path(p) => crate::model::path_string(p),
                SpecRef::Lean(s) => s.clone(),
            };
            let recorded = entry.and_then(|m| m.obligation.iter().find(|o| o.label == label));
            match (entry, recorded) {
                (Some(m), Some(o)) => {
                    let spec_changed =
                        !o.spec_block.is_empty() && keys.get(&o.spec_block) != Some(&o.spec_hash);
                    let status = if !changed.is_empty() || spec_changed {
                        "stale".to_string()
                    } else {
                        o.status.clone()
                    };
                    ObligationState {
                        label: label.clone(),
                        spec: spec_text,
                        spec_lean: o.spec.clone(),
                        status,
                        axioms: o.axioms.clone(),
                        proof: o.proof.clone(),
                        theorem: o.theorem(&m.lean),
                    }
                }
                _ => ObligationState {
                    label: label.clone(),
                    spec: spec_text,
                    spec_lean: String::new(),
                    status: "unextracted".to_string(),
                    axioms: Vec::new(),
                    proof: String::new(),
                    theorem: String::new(),
                },
            }
        })
        .collect();
    ModelState {
        rust: f.rust.clone(),
        lean: entry.map(|m| m.lean.clone()).unwrap_or_default(),
        file: f.file.clone(),
        doc_file: f.doc_file(crate_ident),
        obligations,
        changed,
    }
}

/// The rustdoc section of a model.
pub fn doc_text(m: &ModelState) -> String {
    let mut s = String::from("\n\n# Verification\n\n");
    if m.lean.is_empty() {
        s.push_str("Not extracted: run `cargo lean-rust extract`.\n");
    } else {
        let _ = writeln!(s, "Lean model: `{}`.\n", m.lean);
    }
    if m.obligations.is_empty() {
        s.push_str("No obligations: the model is for theorems written in Lean.\n");
    } else {
        s.push_str("| Obligation | Spec | State | Theorem | Axioms |\n|---|---|---|---|---|\n");
        for o in &m.obligations {
            let spec = if o.spec_lean.is_empty() {
                format!("`{}`", o.spec)
            } else {
                format!("`{}`", o.spec_lean)
            };
            let theorem = if o.theorem.is_empty() {
                String::new()
            } else {
                format!("`{}`", o.theorem)
            };
            let _ = writeln!(
                s,
                "| `{}` | {spec} | {} | {theorem} | {} |",
                o.label,
                o.status,
                o.axioms.join(", ")
            );
        }
    }
    s
}

/// One warning per model with stale or unextracted obligations.
pub fn warnings(states: &[ModelState]) -> Vec<String> {
    let mut out = Vec::new();
    for m in states {
        let stale = m.obligations.iter().filter(|o| o.status == "stale").count();
        let unextracted = m
            .obligations
            .iter()
            .filter(|o| o.status == "unextracted")
            .count();
        if m.lean.is_empty() {
            out.push(format!(
                "lean-rust: {}: not extracted (run `cargo lean-rust extract`)",
                m.rust
            ));
            continue;
        }
        if stale > 0 {
            let why = if m.changed.is_empty() {
                "a spec changed".to_string()
            } else {
                format!("{} changed", m.changed.join(", "))
            };
            let n = if stale == 1 {
                "1 obligation is".to_string()
            } else {
                format!("{stale} obligations are")
            };
            out.push(format!(
                "lean-rust: {}: {n} stale ({why} since `cargo lean-rust extract`)",
                m.rust
            ));
        }
        if unextracted > 0 {
            out.push(format!(
                "lean-rust: {}: {unextracted} obligations are not extracted (run `cargo lean-rust extract`)",
                m.rust
            ));
        }
    }
    out
}

/// The obligations that are not `proved`, as `crate::f: label (state)`.
pub fn not_proved(states: &[ModelState]) -> Vec<String> {
    let mut out = Vec::new();
    for m in states {
        for o in &m.obligations {
            if o.status != "proved" {
                out.push(format!("{}: {} ({})", m.rust, o.label, o.status));
            }
        }
    }
    out
}

/// The table of `cargo lean-rust status`.
pub fn table(states: &[ModelState]) -> String {
    let mut s = String::new();
    for m in states {
        let _ = writeln!(s, "{}", m.rust);
        if m.obligations.is_empty() {
            let state = if m.lean.is_empty() {
                "unextracted"
            } else {
                "model only"
            };
            let _ = writeln!(s, "  {state}");
        }
        let w = m
            .obligations
            .iter()
            .map(|o| o.label.len())
            .max()
            .unwrap_or(0);
        for o in &m.obligations {
            let detail = match o.status.as_str() {
                "proved" | "axioms" => format!("axioms: {}", o.axioms.join(", ")),
                "sorry" | "mismatch" | "failed" => o.proof.clone(),
                "missing" => format!("theorem {} not found", o.theorem),
                _ => String::new(),
            };
            let _ = writeln!(s, "  {:w$}  {:8}  {detail}", o.label, o.status, w = w);
        }
    }
    s
}

/// The JSON of `cargo lean-rust status --output json`.
pub fn json(states: &[ModelState]) -> serde_json::Value {
    serde_json::Value::Array(
        states
            .iter()
            .map(|m| {
                serde_json::json!({
                    "rust": m.rust,
                    "lean": m.lean,
                    "file": m.file,
                    "changed": m.changed,
                    "obligations": m.obligations.iter().map(|o| serde_json::json!({
                        "label": o.label,
                        "spec": o.spec,
                        "spec_lean": o.spec_lean,
                        "status": o.status,
                        "axioms": o.axioms,
                        "proof": o.proof,
                        "theorem": o.theorem,
                    })).collect::<Vec<_>>(),
                })
            })
            .collect(),
    )
}
