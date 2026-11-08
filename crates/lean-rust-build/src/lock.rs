//! The lockfile `lean-rust.lock`: the items each model was extracted from, with the hashes of
//! their tokens, and the state of the proof of each obligation.

use serde::Deserialize;
use std::fmt::Write;
use std::path::Path;

/// The version of the lockfile format.
pub const LOCK_VERSION: u32 = 1;

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct Lock {
    pub version: u32,
    #[serde(default)]
    pub aeneas: String,
    #[serde(default)]
    pub charon: String,
    #[serde(default)]
    pub model: Vec<Model>,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct Model {
    /// The unit name of the Rust function (`crate::sort::insert_sorted`).
    pub rust: String,
    /// The Lean name of the model.
    pub lean: String,
    #[serde(default)]
    pub items: Vec<LockItem>,
    #[serde(default)]
    pub obligation: Vec<Obligation>,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct LockItem {
    pub rust: String,
    pub hash: String,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct Obligation {
    pub label: String,
    /// The Lean name of the spec.
    pub spec: String,
    /// The module path of the `lean!` block defining the spec (`crate::spec::sorting`).
    #[serde(default)]
    pub spec_block: String,
    /// The cache key of that block when the obligation was extracted.
    #[serde(default)]
    pub spec_key: String,
    /// SHA-256 of the statement of the obligation and the spec key.
    pub hash: String,
    /// `proved`, `sorry`, `axioms`, `missing`, `mismatch`, `failed` or `unchecked`.
    pub status: String,
    #[serde(default)]
    pub axioms: Vec<String>,
    /// `lean/Proofs/Sort.lean:14`: the declaration of the proof.
    #[serde(default)]
    pub proof: String,
}

impl Obligation {
    /// `<model>.obligation.<label>`.
    pub fn statement(&self, model: &str) -> String {
        format!("{model}.obligation.{}", self.label)
    }

    /// `<model>.proof.<label>`.
    pub fn theorem(&self, model: &str) -> String {
        format!("{model}.proof.{}", self.label)
    }
}

fn quote(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

impl Lock {
    /// Reads `path`; a missing file is an empty lockfile.
    pub fn read(path: &Path) -> Result<Lock, String> {
        let text = match std::fs::read_to_string(path) {
            Ok(t) => t,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                return Ok(Lock {
                    version: LOCK_VERSION,
                    ..Lock::default()
                })
            }
            Err(e) => return Err(format!("{}: {e}", path.display())),
        };
        let lock: Lock = toml::from_str(&text).map_err(|e| format!("{}: {e}", path.display()))?;
        if lock.version != LOCK_VERSION {
            return Err(format!(
                "{}: version {} is not supported (this lean-rust writes version {LOCK_VERSION})",
                path.display(),
                lock.version
            ));
        }
        Ok(lock)
    }

    pub fn model(&self, rust: &str) -> Option<&Model> {
        self.model.iter().find(|m| m.rust == rust)
    }

    /// The TOML text of the lockfile.
    pub fn to_toml(&self) -> String {
        let mut s = String::new();
        let _ = writeln!(s, "version = {}", self.version);
        let _ = writeln!(s, "aeneas = {}", quote(&self.aeneas));
        let _ = writeln!(s, "charon = {}", quote(&self.charon));
        for m in &self.model {
            let _ = writeln!(s, "\n[[model]]");
            let _ = writeln!(s, "rust = {}", quote(&m.rust));
            let _ = writeln!(s, "lean = {}", quote(&m.lean));
            let _ = writeln!(s, "items = [");
            for i in &m.items {
                let _ = writeln!(
                    s,
                    "  {{ rust = {}, hash = {} }},",
                    quote(&i.rust),
                    quote(&i.hash)
                );
            }
            let _ = writeln!(s, "]");
            for o in &m.obligation {
                let _ = writeln!(s, "\n[[model.obligation]]");
                let _ = writeln!(s, "label = {}", quote(&o.label));
                let _ = writeln!(s, "spec = {}", quote(&o.spec));
                let _ = writeln!(s, "spec_block = {}", quote(&o.spec_block));
                let _ = writeln!(s, "spec_key = {}", quote(&o.spec_key));
                let _ = writeln!(s, "hash = {}", quote(&o.hash));
                let _ = writeln!(s, "status = {}", quote(&o.status));
                let axioms: Vec<String> = o.axioms.iter().map(|a| quote(a)).collect();
                let _ = writeln!(s, "axioms = [{}]", axioms.join(", "));
                let _ = writeln!(s, "proof = {}", quote(&o.proof));
            }
        }
        s
    }
}
