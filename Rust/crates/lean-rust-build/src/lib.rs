//! Build script support of lean-rust.
//!
//! The `main` of the build script (`build.rs`):
//!
//! ```no_run
//! lean_rust_build::Builder::new().compile().unwrap();
//! ```
//!
//! [`Builder::compile`] finds the `lean!` blocks in `src/**/*.rs`, and for each block copies the
//! cached Rust module from `.lean-rust/cache/` to `OUT_DIR`. Blocks without a cache entry are
//! written into the crate's Lean package (`lean/LeanRustGen/Embed/`), checked with `lake build`
//! and generated with `lean-rust module generate`.
//!
//! It also compares the `#[lean_rust::model]` functions with the lockfile `lean-rust.lock`
//! (without Lean or Charon), reports the stale and unextracted obligations with
//! `cargo:warning`, and writes the rustdoc of their states.
//!
//! Environment variables: `LEAN_RUST_CLI` (the `lean-rust` executable, default from `PATH`),
//! `LEAN_RUST_OFFLINE=1` (use the cache only), `LEAN_RUST_EXTRACTING=1` (set by
//! `cargo lean-rust extract`: use the cache only and skip the lockfile),
//! `LEAN_RUST_REQUIRE=proved` (fail unless every obligation is proved, as
//! `[package.metadata.lean-rust] require = "proved"`).

pub mod gen;
pub mod lock;
pub mod model;
pub mod syntax;
pub mod verify;

use model::file_module;
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use syn::visit::Visit;
use syntax::{file_hash, normalize_path, LeanBlock};

/// Version of the generated code: the `lean-rust --generator-version` this crate works with, and part of every
/// cache key.
pub const GENERATOR_VERSION: &str = "3";

/// The Lean toolchain of the crate's Lean package (`lean/lean-toolchain`).
pub const LEAN_TOOLCHAIN: &str = "leanprover/lean4:v4.35.0";

/// `LeanRust/Instances.lean` of lean-rust's Lean library: the `rust_instances` command, written
/// to `lean/LeanRustGen/Lib/Instances.lean` for the `lean!` blocks that use it.
pub const INSTANCES_LEAN: &str = include_str!("../lean/Instances.lean");

/// `LeanRust/AeneasModel.lean` of lean-rust's Lean library: the classes of the laws of Rust's
/// traits over Aeneas's models, written to `lean/LeanRustGen/Lib/AeneasModel.lean` by
/// `cargo lean-rust extract` for the obligations of generic functions.
pub const AENEAS_MODEL_LEAN: &str = include_str!("../lean/AeneasModel.lean");

/// The module of [`INSTANCES_LEAN`] in the crate's Lean package.
pub const INSTANCES_MODULE: &str = "LeanRustGen.Lib.Instances";

/// An error of the build script, with a message for the user.
pub struct Error {
    message: String,
}

impl Error {
    fn new(message: impl Into<String>) -> Self {
        Error {
            message: message.into(),
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl fmt::Debug for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for Error {}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::new(e.to_string())
    }
}

/// A `lean!` block found in the crate.
#[derive(Debug, Clone)]
pub struct Block {
    /// Path of the Rust file relative to the crate root (`src/lib.rs`).
    pub file: String,
    /// [`syntax::file_hash`] of `file`.
    pub file_hash: String,
    /// Name of the Rust module (and of the Lean namespace).
    pub name: String,
    /// Rust module path of the block (`crate::geometry::shapes` as segments after `crate`).
    pub path: Vec<String>,
    pub imports: Vec<String>,
    /// The blocks this one uses, as module paths.
    pub uses: Vec<Vec<String>>,
    /// The Lean source as written (before removing the common indentation).
    pub source: String,
    /// Line of the Rust file where the source literal starts.
    pub line: usize,
}

impl Block {
    /// `LeanRustGen.Embed.<crate>.h<file hash>.<name>`.
    pub fn lean_module(&self, crate_ident: &str) -> String {
        format!(
            "LeanRustGen.Embed.{crate_ident}.h{}.{}",
            self.file_hash, self.name
        )
    }

    /// Path of the Lean file in the Lean package.
    pub fn lean_file(&self, crate_ident: &str) -> PathBuf {
        Path::new("LeanRustGen")
            .join("Embed")
            .join(crate_ident)
            .join(format!("h{}", self.file_hash))
            .join(format!("{}.lean", self.name))
    }

    /// Path of the generated module below `OUT_DIR`.
    pub fn out_file(&self) -> PathBuf {
        Path::new("lean_rust")
            .join(&self.file_hash)
            .join(format!("{}.rs", self.name))
    }

    /// `true` when the source uses `rust_instances`, which imports [`INSTANCES_MODULE`].
    pub fn uses_instances(&self) -> bool {
        self.source.contains("rust_instances")
    }
}

/// Configures and runs the build step.
pub struct Builder {
    manifest_dir: PathBuf,
    out_dir: PathBuf,
    crate_name: String,
}

impl Default for Builder {
    fn default() -> Self {
        Self::new()
    }
}

fn env_required(name: &str) -> PathBuf {
    match std::env::var_os(name) {
        Some(v) => PathBuf::from(v),
        None => panic!("lean-rust-build: {name} is not set (run from a build script)"),
    }
}

impl Builder {
    /// A builder for the crate of the running build script (`CARGO_MANIFEST_DIR`, `OUT_DIR`,
    /// `CARGO_PKG_NAME`).
    pub fn new() -> Self {
        Builder {
            manifest_dir: env_required("CARGO_MANIFEST_DIR"),
            out_dir: env_required("OUT_DIR"),
            crate_name: std::env::var("CARGO_PKG_NAME")
                .expect("lean-rust-build: CARGO_PKG_NAME is not set"),
        }
    }

    /// A builder for an explicit crate directory, output directory and crate name.
    pub fn with_dirs(
        manifest_dir: impl Into<PathBuf>,
        out_dir: impl Into<PathBuf>,
        crate_name: impl Into<String>,
    ) -> Self {
        Builder {
            manifest_dir: manifest_dir.into(),
            out_dir: out_dir.into(),
            crate_name: crate_name.into(),
        }
    }

    pub fn crate_ident(&self) -> String {
        self.crate_name.replace('-', "_")
    }

    pub fn cache_dir(&self) -> PathBuf {
        self.manifest_dir.join(".lean-rust").join("cache")
    }

    pub fn lean_dir(&self) -> PathBuf {
        self.manifest_dir.join("lean")
    }

    /// The lockfile of the crate.
    pub fn lock_path(&self) -> PathBuf {
        self.manifest_dir.join("lean-rust.lock")
    }

    /// The `@[csimp]` replacements `cargo lean-rust check` writes.
    pub fn csimp_path(&self) -> PathBuf {
        self.lean_dir().join("LeanRustGen").join("Csimp.lean")
    }

    /// The part of every cache key that depends on the `@[csimp]` replacements.
    pub fn csimp_key(&self) -> String {
        match fs::read(self.csimp_path()) {
            Ok(text) => Sha256::digest(&text)
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect(),
            Err(_) => String::new(),
        }
    }

    /// Generates the Rust modules of all `lean!` blocks of the crate into `OUT_DIR`, and
    /// compares the modelled functions with the lockfile.
    pub fn compile(&self) -> Result<(), Error> {
        println!("cargo:rerun-if-env-changed=LEAN_RUST_EXTRACTING");
        println!("cargo:rerun-if-env-changed=LEAN_RUST_OFFLINE");
        println!("cargo:rerun-if-env-changed=LEAN_RUST_CLI");
        println!("cargo:rerun-if-env-changed=LEAN_RUST_REQUIRE");
        let extracting = std::env::var("LEAN_RUST_EXTRACTING").as_deref() == Ok("1");
        self.check_toolchain()?;
        let (blocks, files) = self.scan()?;
        for f in &files {
            println!("cargo:rerun-if-changed={}", f.display());
        }
        let src = self.manifest_dir.join("src");
        if src.is_dir() {
            println!("cargo:rerun-if-changed={}", src.display());
        }
        let keys = cache_keys(&self.crate_name, &blocks, &self.csimp_key())?;
        let cache = self.cache_dir();
        let mut missing = Vec::new();
        for (i, b) in blocks.iter().enumerate() {
            let cached = cache.join(format!("{}.rs", keys[i]));
            if cached.is_file() {
                write_if_changed(&self.out_dir.join(b.out_file()), &fs::read(&cached)?)?;
            } else {
                missing.push(i);
            }
        }
        if !missing.is_empty() && !extracting {
            if std::env::var("LEAN_RUST_OFFLINE").as_deref() == Ok("1") {
                let names: Vec<String> = missing
                    .iter()
                    .map(|&i| {
                        format!(
                            "  {} ({}::{})",
                            blocks[i].file,
                            module_path_string(&blocks[i].path),
                            keys[i]
                        )
                    })
                    .collect();
                return Err(Error::new(format!(
                    "lean-rust-build: LEAN_RUST_OFFLINE=1 and these lean! blocks are not in {}:\n{}",
                    cache.display(),
                    names.join("\n")
                )));
            }
            self.generate(&blocks, &keys, &missing)?;
        }
        if cache.is_dir() {
            println!("cargo:rerun-if-changed={}", cache.display());
        }
        for f in self.lean_user_files() {
            println!("cargo:rerun-if-changed={}", f.display());
        }
        println!("cargo:rerun-if-changed={}", self.lock_path().display());
        let doc_dir = self.out_dir.join("lean_rust").join("doc");
        fs::create_dir_all(&doc_dir)?;
        if extracting {
            return Ok(());
        }
        println!(
            "cargo:rerun-if-changed={}",
            self.model_dir()
                .join("FunsExternal_Template.lean")
                .display()
        );
        let offline = std::env::var("LEAN_RUST_OFFLINE").as_deref() == Ok("1");
        self.compile_opaque(&self.scan_items()?, offline)?;
        self.verify(&blocks, &doc_dir)
    }

    /// Generates the cache entries of the `blocks` that `select` accepts and that are not
    /// cached (with `lake build` and `lean-rust module generate`).
    pub fn generate_cache(
        &self,
        blocks: &[Block],
        select: impl Fn(&Block) -> bool,
    ) -> Result<(), Error> {
        let keys = cache_keys(&self.crate_name, blocks, &self.csimp_key())?;
        let cache = self.cache_dir();
        let missing: Vec<usize> = (0..blocks.len())
            .filter(|&i| select(&blocks[i]) && !cache.join(format!("{}.rs", keys[i])).is_file())
            .collect();
        if missing.is_empty() {
            return Ok(());
        }
        self.generate(blocks, &keys, &missing)
    }

    fn check_toolchain(&self) -> Result<(), Error> {
        let file = self.lean_dir().join("lean-toolchain");
        match fs::read_to_string(&file) {
            Ok(t) if t.trim() != LEAN_TOOLCHAIN => Err(Error::new(format!(
                "lean-rust-build: {} is `{}`; this lean-rust needs `{LEAN_TOOLCHAIN}`",
                file.display(),
                t.trim()
            ))),
            _ => Ok(()),
        }
    }

    /// The modelled functions, opaque functions, `use`s and item hashes of `src/**/*.rs`.
    pub fn scan_items(&self) -> Result<model::CrateItems, Error> {
        let mut files = Vec::new();
        collect_rs(&self.manifest_dir.join("src"), &mut files)?;
        files.sort();
        let mut items = model::CrateItems::default();
        for f in &files {
            let rel = normalize_path(f.strip_prefix(&self.manifest_dir).unwrap_or(f));
            let text = fs::read_to_string(f)?;
            let ast = syn::parse_file(&text)
                .map_err(|e| Error::new(format!("lean-rust-build: cannot parse {rel}: {e}")))?;
            model::scan_file(&rel, file_module(&rel), &ast, &mut items);
        }
        Ok(items)
    }

    /// The current hashes of the specs: `sha256:<cache key>` of the blocks (without the
    /// `@[csimp]` replacements) by module path, and the hashes of the other functions by unit
    /// name.
    pub fn spec_hashes(
        &self,
        blocks: &[Block],
        items: &model::CrateItems,
    ) -> Result<BTreeMap<String, String>, Error> {
        let keys = cache_keys(&self.crate_name, blocks, "")?;
        let mut out: BTreeMap<String, String> = items.hashes.clone();
        for (b, k) in blocks.iter().zip(&keys) {
            out.insert(module_path_string(&b.path), format!("sha256:{k}"));
        }
        Ok(out)
    }

    /// `require = "proved"` of `[package.metadata.lean-rust]`, or `LEAN_RUST_REQUIRE`.
    fn require_proved(&self) -> Result<bool, Error> {
        if let Ok(v) = std::env::var("LEAN_RUST_REQUIRE") {
            return Ok(v == "proved");
        }
        let manifest = self.manifest_dir.join("Cargo.toml");
        let Ok(text) = fs::read_to_string(&manifest) else {
            return Ok(false);
        };
        let value: toml::Value = toml::from_str(&text)
            .map_err(|e| Error::new(format!("lean-rust-build: {}: {e}", manifest.display())))?;
        let require = value
            .get("package")
            .and_then(|p| p.get("metadata"))
            .and_then(|m| m.get("lean-rust"))
            .and_then(|l| l.get("require"))
            .and_then(|r| r.as_str());
        match require {
            None => Ok(false),
            Some("proved") => Ok(true),
            Some(other) => Err(Error::new(format!(
                "lean-rust-build: {}: [package.metadata.lean-rust] require = \"{other}\"; the supported value is \"proved\"",
                manifest.display()
            ))),
        }
    }

    fn verify(&self, blocks: &[Block], doc_dir: &Path) -> Result<(), Error> {
        let items = self.scan_items()?;
        if !items.errors.is_empty() {
            return Err(Error::new(format!(
                "lean-rust-build: invalid #[lean_rust::model]:\n{}",
                items.errors.join("\n")
            )));
        }
        if items.models.is_empty() {
            return Ok(());
        }
        let lock = lock::Lock::read(&self.lock_path()).map_err(Error::new)?;
        let spec_hashes = self.spec_hashes(blocks, &items)?;
        let states = verify::states(&items, &lock, &spec_hashes, &self.crate_ident());
        for m in &states {
            write_if_changed(&doc_dir.join(&m.doc_file), verify::doc_text(m).as_bytes())?;
        }
        for w in verify::warnings(&states) {
            println!("cargo:warning={w}");
        }
        if self.require_proved()? {
            let bad = verify::not_proved(&states);
            if !bad.is_empty() {
                return Err(Error::new(format!(
                    "lean-rust-build: require = \"proved\" and these obligations are not proved:\n  {}",
                    bad.join("\n  ")
                )));
            }
        }
        Ok(())
    }

    /// The `lean!` blocks of `src/**/*.rs` and the scanned files.
    pub fn scan(&self) -> Result<(Vec<Block>, Vec<PathBuf>), Error> {
        let mut files = Vec::new();
        collect_rs(&self.manifest_dir.join("src"), &mut files)?;
        files.sort();
        let mut blocks = Vec::new();
        for f in &files {
            let rel = normalize_path(f.strip_prefix(&self.manifest_dir).unwrap_or(f));
            let text = fs::read_to_string(f)?;
            let ast = syn::parse_file(&text)
                .map_err(|e| Error::new(format!("lean-rust-build: cannot parse {rel}: {e}")))?;
            let mut v = Scanner {
                file: rel.clone(),
                hash: file_hash(&rel),
                module: file_module(&rel),
                blocks: Vec::new(),
                error: None,
            };
            v.visit_file(&ast);
            if let Some(e) = v.error {
                return Err(e);
            }
            blocks.extend(v.blocks);
        }
        let mut seen: HashMap<Vec<String>, &Block> = HashMap::new();
        for b in &blocks {
            if let Some(o) = seen.insert(b.path.clone(), b) {
                return Err(Error::new(format!(
                    "lean-rust-build: two lean! blocks define {} ({} and {})",
                    module_path_string(&b.path),
                    o.file,
                    b.file
                )));
            }
        }
        Ok((blocks, files))
    }

    fn lean_user_files(&self) -> Vec<PathBuf> {
        let mut out = Vec::new();
        let lean = self.lean_dir();
        if lean.is_dir() {
            collect_user_files(&lean, &lean, &mut out);
        }
        out.sort();
        out
    }

    fn ensure_package(&self) -> Result<(), Error> {
        let lean = self.lean_dir();
        if lean.join("lakefile.toml").exists() || lean.join("lakefile.lean").exists() {
            return Ok(());
        }
        fs::create_dir_all(&lean)?;
        let lakefile = format!(
            "name = \"{}\"\ndefaultTargets = [\"LeanRustGen\"]\n\n[[lean_lib]]\nname = \"LeanRustGen\"\nglobs = [\"LeanRustGen.+\"]\n",
            self.crate_ident()
        );
        fs::write(lean.join("lakefile.toml"), lakefile)?;
        fs::write(lean.join("lean-toolchain"), format!("{LEAN_TOOLCHAIN}\n"))?;
        fs::write(lean.join(".gitignore"), "/.lake/\n")?;
        Ok(())
    }

    fn generate(&self, blocks: &[Block], keys: &[String], missing: &[usize]) -> Result<(), Error> {
        let model = self
            .lean_dir()
            .join("LeanRustGen")
            .join("Model")
            .join(self.crate_ident());
        if !model.is_dir() {
            if let Some(&i) = missing
                .iter()
                .find(|&&i| depends_on_model(&blocks[i], blocks))
            {
                return Err(Error::new(format!(
                    "lean-rust-build: the lean! block {} ({}) imports the model of the crate, which `cargo lean-rust extract` writes: run it first",
                    module_path_string(&blocks[i].path),
                    blocks[i].file
                )));
            }
        }
        let cli = std::env::var_os("LEAN_RUST_CLI")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("lean-rust"));
        let version = run_output(
            Command::new(&cli).arg("--generator-version"),
            &cli.display().to_string(),
        )?;
        if version.trim() != GENERATOR_VERSION {
            return Err(Error::new(format!(
                "lean-rust-build: {} generates code of version `{}`; this build needs version `{GENERATOR_VERSION}`",
                cli.display(),
                version.trim()
            )));
        }
        self.ensure_package()?;
        let lean = self.lean_dir();
        let crate_ident = self.crate_ident();
        let by_path: HashMap<&[String], &Block> =
            blocks.iter().map(|b| (b.path.as_slice(), b)).collect();
        let mut sources = Vec::new();
        for b in blocks {
            let used: Vec<&Block> = b.uses.iter().map(|p| by_path[p.as_slice()]).collect();
            let (text, header_lines, indent) = lean_source(b, &used, &crate_ident);
            write_if_changed(&lean.join(b.lean_file(&crate_ident)), text.as_bytes())?;
            sources.push((header_lines, indent));
        }
        let lib = lean.join("LeanRustGen").join("Lib").join("Instances.lean");
        if blocks.iter().any(Block::uses_instances) {
            write_if_changed(&lib, INSTANCES_LEAN.as_bytes())?;
        } else if lib.is_file() {
            fs::remove_file(&lib)?;
        }
        prune_dir(
            &lean.join("LeanRustGen").join("Embed").join(&crate_ident),
            &blocks
                .iter()
                .map(|b| lean.join(b.lean_file(&crate_ident)))
                .collect(),
        )?;
        let csimp = self.csimp_path().is_file();
        let mut modules: Vec<String> = missing
            .iter()
            .map(|&i| blocks[i].lean_module(&crate_ident))
            .collect();
        if csimp {
            modules.push("LeanRustGen.Csimp".to_string());
        }
        let build = Command::new("lake")
            .arg("build")
            .args(&modules)
            .current_dir(&lean)
            .output()
            .map_err(|e| Error::new(format!("lean-rust-build: cannot run lake: {e}")))?;
        let log = format!(
            "{}{}",
            String::from_utf8_lossy(&build.stdout),
            String::from_utf8_lossy(&build.stderr)
        );
        let diagnostics = map_diagnostics(&log, blocks, &sources, &crate_ident);
        for d in &diagnostics {
            for (i, line) in d.lines().enumerate() {
                if i == 0 {
                    println!("cargo:warning={line}");
                } else {
                    println!("cargo:warning=  {line}");
                }
            }
            eprintln!("{d}");
        }
        if !build.status.success() {
            let detail = if diagnostics.is_empty() {
                log
            } else {
                diagnostics.join("\n")
            };
            return Err(Error::new(format!(
                "lean-rust-build: Lean rejected the lean! blocks:\n{detail}"
            )));
        }
        let lean_path = run_output(
            Command::new("lake")
                .args(["env", "printenv", "LEAN_PATH"])
                .current_dir(&lean),
            "lake env",
        )?;
        let tmp = self.out_dir.join("lean_rust").join("tmp");
        fs::create_dir_all(&tmp)?;
        let jobs: Vec<serde_json::Value> = missing
            .iter()
            .map(|&i| {
                let type_paths: serde_json::Map<String, serde_json::Value> =
                    used_closure(i, blocks, &by_path)
                        .into_iter()
                        .map(|u| (u.name.clone(), module_path_string(&u.path).into()))
                        .collect();
                serde_json::json!({
                    "module": blocks[i].lean_module(&crate_ident),
                    "namespace": blocks[i].name,
                    "type_paths": type_paths,
                    "model_namespace": crate_ident,
                    "output_file": tmp.join(format!("{}.rs", keys[i])).to_string_lossy(),
                })
            })
            .collect();
        let batch = tmp.join("batch.json");
        fs::write(&batch, serde_json::Value::Array(jobs).to_string())?;
        let mut cmd = Command::new(&cli);
        cmd.current_dir(&lean)
            .args(["module", "generate", "--batch"])
            .arg(&batch);
        if csimp {
            cmd.args(["--import", "LeanRustGen.Csimp"]);
        }
        cmd.args(["--output", "json", "--search-path"]);
        for p in lean_path.trim().split(':').filter(|p| !p.is_empty()) {
            cmd.arg(p);
        }
        let out = cmd.output().map_err(|e| {
            Error::new(format!(
                "lean-rust-build: cannot run {}: {e}",
                cli.display()
            ))
        })?;
        let summary: Option<serde_json::Value> = serde_json::from_slice(&out.stdout).ok();
        let mut errors = Vec::new();
        if let Some(serde_json::Value::Array(items)) = &summary {
            for (j, item) in items.iter().enumerate() {
                let b = &blocks[missing[j]];
                if let Some(e) = item.get("error").and_then(|e| e.as_str()) {
                    errors.push(format!("{} ({}): {e}", b.file, module_path_string(&b.path)));
                }
                if let Some(serde_json::Value::Array(sk)) = item.get("skipped") {
                    for s in sk {
                        println!(
                            "cargo:warning={} ({}): not public: {}: {}",
                            b.file,
                            module_path_string(&b.path),
                            s.get("name").and_then(|v| v.as_str()).unwrap_or(""),
                            s.get("reason").and_then(|v| v.as_str()).unwrap_or("")
                        );
                    }
                }
            }
        }
        if !out.status.success() || summary.is_none() {
            if errors.is_empty() {
                errors.push(String::from_utf8_lossy(&out.stderr).into_owned());
            }
            return Err(Error::new(format!(
                "lean-rust-build: lean-rust module generate failed:\n{}",
                errors.join("\n")
            )));
        }
        let cache = self.cache_dir();
        fs::create_dir_all(&cache)?;
        for &i in missing {
            let gen = tmp.join(format!("{}.rs", keys[i]));
            run_output(
                Command::new("rustfmt")
                    .args(["--edition", "2021"])
                    .arg(&gen),
                "rustfmt",
            )?;
            let text = fs::read(&gen)?;
            fs::write(cache.join(format!("{}.rs", keys[i])), &text)?;
            write_if_changed(&self.out_dir.join(blocks[i].out_file()), &text)?;
        }
        let mut live: BTreeSet<PathBuf> =
            keys.iter().map(|k| cache.join(format!("{k}.rs"))).collect();
        for o in self.opaque_models(&self.scan_items()?)? {
            live.insert(cache.join(format!("{}.rs", o.key)));
        }
        prune_dir(&cache, &live)?;
        Ok(())
    }
}

struct Scanner {
    file: String,
    hash: String,
    module: Vec<String>,
    blocks: Vec<Block>,
    error: Option<Error>,
}

impl<'ast> Visit<'ast> for Scanner {
    fn visit_item_mod(&mut self, m: &'ast syn::ItemMod) {
        self.module.push(m.ident.to_string());
        syn::visit::visit_item_mod(self, m);
        self.module.pop();
    }

    fn visit_macro(&mut self, mac: &'ast syn::Macro) {
        let segs: Vec<String> = mac
            .path
            .segments
            .iter()
            .map(|s| s.ident.to_string())
            .collect();
        let is_lean = matches!(segs.as_slice(), [l] if l == "lean")
            || matches!(segs.as_slice(), [c, l] if c == "lean_rust" && l == "lean");
        if !is_lean {
            syn::visit::visit_macro(self, mac);
            return;
        }
        match mac.parse_body::<LeanBlock>() {
            Ok(b) => {
                let name = b.name.to_string();
                let mut path = self.module.clone();
                path.push(name.clone());
                let uses = b
                    .uses
                    .iter()
                    .map(|p| resolve_path(&self.module, p))
                    .collect();
                self.blocks.push(Block {
                    file: self.file.clone(),
                    file_hash: self.hash.clone(),
                    name,
                    path,
                    imports: b.imports,
                    uses,
                    source: b.source.value(),
                    line: b.source.span().start().line,
                });
            }
            Err(e) => {
                let at = e.span().start();
                self.error.get_or_insert(Error::new(format!(
                    "lean-rust-build: {}:{}:{}: invalid lean! block: {e}",
                    self.file,
                    at.line,
                    at.column + 1
                )));
            }
        }
    }
}

fn resolve_path(module: &[String], p: &syn::Path) -> Vec<String> {
    let segs: Vec<String> = p.segments.iter().map(|s| s.ident.to_string()).collect();
    let mut out: Vec<String> = Vec::new();
    let mut rest = segs.as_slice();
    match rest.first().map(String::as_str) {
        Some("crate") => rest = &rest[1..],
        Some("self") => {
            out = module.to_vec();
            rest = &rest[1..];
        }
        Some("super") => {
            out = module.to_vec();
            while rest.first().is_some_and(|s| s == "super") {
                out.pop();
                rest = &rest[1..];
            }
        }
        _ => out = module.to_vec(),
    }
    out.extend(rest.iter().cloned());
    out
}

/// The blocks `blocks[i]` uses, directly or through other blocks.
fn used_closure<'a>(
    i: usize,
    blocks: &'a [Block],
    by_path: &HashMap<&[String], &'a Block>,
) -> Vec<&'a Block> {
    let mut out: Vec<&Block> = Vec::new();
    let mut stack: Vec<&[String]> = blocks[i].uses.iter().map(Vec::as_slice).collect();
    while let Some(p) = stack.pop() {
        let u = by_path[p];
        if out.iter().any(|o| o.path == u.path) {
            continue;
        }
        out.push(u);
        stack.extend(u.uses.iter().map(Vec::as_slice));
    }
    out
}

pub fn module_path_string(path: &[String]) -> String {
    let mut s = String::from("crate");
    for p in path {
        s.push_str("::");
        s.push_str(p);
    }
    s
}

/// The cache key of every block: SHA-256 over the crate name, the file, the block name, the
/// imports, the source, the keys of the used blocks, `extra` (the hash of the `@[csimp]`
/// replacements) and [`GENERATOR_VERSION`].
pub fn cache_keys(crate_name: &str, blocks: &[Block], extra: &str) -> Result<Vec<String>, Error> {
    let index: HashMap<&[String], usize> = blocks
        .iter()
        .enumerate()
        .map(|(i, b)| (b.path.as_slice(), i))
        .collect();
    let mut keys: Vec<Option<String>> = vec![None; blocks.len()];
    fn key_of(
        i: usize,
        crate_name: &str,
        extra: &str,
        blocks: &[Block],
        index: &HashMap<&[String], usize>,
        keys: &mut Vec<Option<String>>,
        stack: &mut Vec<usize>,
    ) -> Result<String, Error> {
        if let Some(k) = &keys[i] {
            return Ok(k.clone());
        }
        let b = &blocks[i];
        if stack.contains(&i) {
            return Err(Error::new(format!(
                "lean-rust-build: lean! blocks use each other in a cycle through {}",
                module_path_string(&b.path)
            )));
        }
        stack.push(i);
        let mut h = Sha256::new();
        for part in [crate_name, &b.file, &b.name] {
            h.update(part.as_bytes());
            h.update([0]);
        }
        for imp in &b.imports {
            h.update(imp.as_bytes());
            h.update([1]);
        }
        h.update([0]);
        h.update(b.source.as_bytes());
        h.update([0]);
        if b.uses_instances() {
            h.update(INSTANCES_LEAN.as_bytes());
        }
        h.update([0]);
        for u in &b.uses {
            let Some(&j) = index.get(u.as_slice()) else {
                return Err(Error::new(format!(
                    "lean-rust-build: {}: `uses` names {}, which is not a lean! block of this crate",
                    b.file,
                    module_path_string(u)
                )));
            };
            h.update(key_of(j, crate_name, extra, blocks, index, keys, stack)?.as_bytes());
            h.update([1]);
        }
        h.update([0]);
        h.update(extra.as_bytes());
        h.update([0]);
        h.update(GENERATOR_VERSION.as_bytes());
        stack.pop();
        let k: String = h.finalize().iter().map(|b| format!("{b:02x}")).collect();
        keys[i] = Some(k.clone());
        Ok(k)
    }
    let mut stack = Vec::new();
    (0..blocks.len())
        .map(|i| key_of(i, crate_name, extra, blocks, &index, &mut keys, &mut stack))
        .collect()
}

/// The Lean file of a block, the number of lines before the source and the indentation
/// removed from the source.
pub fn lean_source(b: &Block, used: &[&Block], crate_ident: &str) -> (String, usize, usize) {
    let mut text = String::new();
    for imp in &b.imports {
        text.push_str(&format!("import {imp}\n"));
    }
    if b.uses_instances() {
        text.push_str(&format!("import {INSTANCES_MODULE}\n"));
    }
    for u in used {
        text.push_str(&format!("import {}\n", u.lean_module(crate_ident)));
    }
    if !used.is_empty() {
        let names: Vec<&str> = used.iter().map(|u| u.name.as_str()).collect();
        text.push_str(&format!("open {}\n", names.join(" ")));
    }
    text.push_str(&format!("namespace {}\n", b.name));
    let header = text.lines().count();
    let indent = b
        .source
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| l.len() - l.trim_start().len())
        .min()
        .unwrap_or(0);
    for line in b.source.lines() {
        if line.trim().is_empty() {
            text.push('\n');
        } else {
            text.push_str(&line[indent.min(line.len())..]);
            text.push('\n');
        }
    }
    text.push_str(&format!("end {}\n", b.name));
    (text, header, indent)
}

/// The diagnostics of a `lake build` log, with the positions of the Lean files of the blocks
/// replaced by the Rust file and line of the `lean!` source.
fn map_diagnostics(
    log: &str,
    blocks: &[Block],
    sources: &[(usize, usize)],
    crate_ident: &str,
) -> Vec<String> {
    let files: Vec<String> = blocks
        .iter()
        .map(|b| normalize_path(&b.lean_file(crate_ident)))
        .collect();
    let mut out: Vec<String> = Vec::new();
    let mut current: Option<String> = None;
    for line in log.lines() {
        let kind = ["error: ", "warning: ", "info: "]
            .iter()
            .find(|p| line.starts_with(**p));
        if let Some(kind) = kind {
            if let Some(d) = current.take() {
                out.push(d);
            }
            let rest = &line[kind.len()..];
            for (i, f) in files.iter().enumerate() {
                let Some(pos) = rest.find(f.as_str()) else {
                    continue;
                };
                let after = &rest[pos + f.len()..];
                let mut parts = after.splitn(4, ':');
                let (Some(""), Some(l), Some(c), Some(msg)) =
                    (parts.next(), parts.next(), parts.next(), parts.next())
                else {
                    continue;
                };
                let (Ok(l), Ok(c)) = (l.parse::<usize>(), c.parse::<usize>()) else {
                    continue;
                };
                let (header, indent) = sources[i];
                let b = &blocks[i];
                let src_line = l.saturating_sub(header);
                let rust_line = b.line + src_line.saturating_sub(1);
                let label = kind.trim_end_matches(": ");
                current = Some(format!(
                    "{}:{}:{}: {label}:{msg}",
                    b.file,
                    rust_line,
                    c + indent + 1
                ));
                break;
            }
        } else if let Some(d) = current.as_mut() {
            let t = line.trim_start();
            if t.starts_with('✖')
                || t.starts_with('✔')
                || t.starts_with("trace:")
                || t.starts_with("Some required")
                || t.starts_with("- ")
            {
                out.push(current.take().unwrap());
            } else {
                d.push('\n');
                d.push_str(line);
            }
        }
    }
    if let Some(d) = current {
        out.push(d);
    }
    out.into_iter().map(|d| d.trim_end().to_string()).collect()
}

fn run_output(cmd: &mut Command, what: &str) -> Result<String, Error> {
    let out = cmd
        .output()
        .map_err(|e| Error::new(format!("lean-rust-build: cannot run {what}: {e}")))?;
    if !out.status.success() {
        return Err(Error::new(format!(
            "lean-rust-build: {what} failed:\n{}{}",
            String::from_utf8_lossy(&out.stdout),
            String::from_utf8_lossy(&out.stderr)
        )));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn write_if_changed(path: &Path, content: &[u8]) -> Result<(), Error> {
    if fs::read(path).ok().as_deref() == Some(content) {
        return Ok(());
    }
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
    }
    fs::write(path, content)?;
    Ok(())
}

/// Removes the files below `dir` that are not in `live`, and the directories left empty.
fn prune_dir(dir: &Path, live: &BTreeSet<PathBuf>) -> Result<(), Error> {
    if !dir.is_dir() {
        return Ok(());
    }
    for e in fs::read_dir(dir)? {
        let p = e?.path();
        if p.is_dir() {
            prune_dir(&p, live)?;
            if fs::read_dir(&p)?.next().is_none() {
                fs::remove_dir(&p)?;
            }
        } else if !live.contains(&p) {
            fs::remove_file(&p)?;
        }
    }
    Ok(())
}

fn collect_rs(dir: &Path, out: &mut Vec<PathBuf>) -> Result<(), Error> {
    if !dir.is_dir() {
        return Ok(());
    }
    for e in fs::read_dir(dir)? {
        let p = e?.path();
        if p.is_dir() {
            collect_rs(&p, out)?;
        } else if p.extension().is_some_and(|x| x == "rs") {
            out.push(p);
        }
    }
    Ok(())
}

fn collect_user_files(root: &Path, dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for e in entries.flatten() {
        let p = e.path();
        let rel = p.strip_prefix(root).unwrap_or(&p);
        let first = rel.components().next().map(|c| c.as_os_str().to_owned());
        if first.as_deref() == Some("LeanRustGen".as_ref())
            || first.as_deref() == Some(".lake".as_ref())
        {
            continue;
        }
        if p.is_dir() {
            collect_user_files(root, &p, out);
        } else {
            out.push(p);
        }
    }
}

/// The rev of Aeneas this lean-rust works with: the `require aeneas` of the crate's Lean
/// package.
pub const AENEAS_REV: &str = "c5eb4a28cef65e0aa27743105308243e535a2a2b";

/// The version of the Charon bundled with that Aeneas.
pub const CHARON_VERSION: &str = "0.1.313";

/// `true` when the block imports the crate's model (`LeanRustGen.Model`, `.Alias` or `.Extern`,
/// written by `cargo lean-rust extract`), directly or through the blocks it uses.
pub fn depends_on_model(b: &Block, blocks: &[Block]) -> bool {
    let mut stack = vec![b];
    let mut seen: Vec<&[String]> = Vec::new();
    while let Some(x) = stack.pop() {
        if seen.contains(&x.path.as_slice()) {
            continue;
        }
        seen.push(&x.path);
        if x.imports.iter().any(|i| {
            [
                "LeanRustGen.Model.",
                "LeanRustGen.Alias.",
                "LeanRustGen.Extern.",
            ]
            .iter()
            .any(|p| i.starts_with(p))
        }) {
            return true;
        }
        stack.extend(blocks.iter().filter(|o| x.uses.contains(&o.path)));
    }
    false
}

/// The Lean model of a `#[lean_rust::opaque]` function, written in `lean/External.lean`.
#[derive(Debug, Clone)]
pub struct OpaqueModel {
    /// The unit name of the Rust function.
    pub rust: String,
    /// The candidate Lean names of the model (relative to the root and to the crate).
    pub lean: Vec<String>,
    /// The cache key of its generated Rust.
    pub key: String,
    /// The path of the generated Rust below `OUT_DIR`.
    pub out_file: PathBuf,
}

fn sha_hex(parts: &[&[u8]]) -> String {
    let mut h = Sha256::new();
    for p in parts {
        h.update(p);
        h.update([0]);
    }
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

impl Builder {
    fn model_dir(&self) -> PathBuf {
        self.lean_dir()
            .join("LeanRustGen")
            .join("Model")
            .join(self.crate_ident())
    }

    /// The opaque functions whose model Aeneas lists in `FunsExternal_Template.lean`, when
    /// `lean/External.lean` defines it.
    pub fn opaque_models(&self, items: &model::CrateItems) -> Result<Vec<OpaqueModel>, Error> {
        let template = self.model_dir().join("FunsExternal_Template.lean");
        let (Ok(template), Ok(external)) = (
            fs::read_to_string(&template),
            fs::read(self.lean_dir().join("External.lean")),
        ) else {
            return Ok(Vec::new());
        };
        let ident = self.crate_ident();
        let decls = gen::parse_aeneas(&template);
        let types = fs::read(self.lean_dir().join("ExternalTypes.lean")).unwrap_or_default();
        let model_types = fs::read(self.model_dir().join("Types.lean")).unwrap_or_default();
        let mut out = Vec::new();
        for o in &items.opaque {
            let unit = &o.unit;
            let Some(d) = decls.iter().find(|d| {
                d.rust
                    .as_deref()
                    .and_then(|r| gen::aeneas_unit(r, &ident))
                    .as_deref()
                    == Some(unit.as_str())
            }) else {
                continue;
            };
            if o.module != file_module(&o.file) {
                continue;
            }
            let lean = vec![d.lean.clone(), format!("{ident}.{}", d.lean)];
            let key = sha_hex(&[
                ident.as_bytes(),
                unit.as_bytes(),
                lean.join(" ").as_bytes(),
                &external,
                &types,
                &model_types,
                GENERATOR_VERSION.as_bytes(),
            ]);
            out.push(OpaqueModel {
                rust: unit.clone(),
                lean,
                key,
                out_file: Path::new("lean_rust")
                    .join("opaque")
                    .join(file_hash(&o.file))
                    .join(format!("{}.rs", o.file_stem())),
            });
        }
        Ok(out)
    }

    /// Writes the Rust of the models of the opaque functions to `OUT_DIR` from the cache,
    /// generating the missing ones with `lean-rust module generate` unless `cached_only`.
    fn compile_opaque(&self, items: &model::CrateItems, cached_only: bool) -> Result<(), Error> {
        let models = self.opaque_models(items)?;
        let cache = self.cache_dir();
        let missing: Vec<&OpaqueModel> = models
            .iter()
            .filter(|m| !cache.join(format!("{}.rs", m.key)).is_file())
            .collect();
        if !missing.is_empty() && !cached_only {
            self.generate_opaque(&missing)?;
        }
        for m in &models {
            if let Ok(text) = fs::read(cache.join(format!("{}.rs", m.key))) {
                write_if_changed(&self.out_dir.join(&m.out_file), &text)?;
            }
        }
        Ok(())
    }

    fn generate_opaque(&self, models: &[&OpaqueModel]) -> Result<(), Error> {
        let cli = std::env::var_os("LEAN_RUST_CLI")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("lean-rust"));
        let lean = self.lean_dir();
        run_output(
            Command::new("lake")
                .args(["build", "External"])
                .current_dir(&lean),
            "lake build External",
        )?;
        let lean_path = run_output(
            Command::new("lake")
                .args(["env", "printenv", "LEAN_PATH"])
                .current_dir(&lean),
            "lake env",
        )?;
        let tmp = self.out_dir.join("lean_rust").join("tmp");
        fs::create_dir_all(&tmp)?;
        let ident = self.crate_ident();
        let jobs: Vec<serde_json::Value> = models
            .iter()
            .map(|m| {
                serde_json::json!({
                    "module": "External",
                    "roots": m.lean,
                    "namespace": ident,
                    "model_namespace": ident,
                    "output_file": tmp.join(format!("{}.rs", m.key)).to_string_lossy(),
                })
            })
            .collect();
        let batch = tmp.join("opaque.json");
        fs::write(&batch, serde_json::Value::Array(jobs).to_string())?;
        let mut cmd = Command::new(&cli);
        cmd.current_dir(&lean)
            .args(["module", "generate", "--batch"])
            .arg(&batch)
            .args(["--output", "json", "--search-path"]);
        for p in lean_path.trim().split(':').filter(|p| !p.is_empty()) {
            cmd.arg(p);
        }
        let summary = run_output(&mut cmd, &format!("{} module generate", cli.display()))?;
        let summary: Vec<serde_json::Value> = serde_json::from_str(&summary).unwrap_or_default();
        let cache = self.cache_dir();
        fs::create_dir_all(&cache)?;
        for (i, m) in models.iter().enumerate() {
            let gen = tmp.join(format!("{}.rs", m.key));
            let mut text = fs::read_to_string(&gen)?;
            let public = summary
                .get(i)
                .and_then(|s| s.get("public"))
                .and_then(|p| p.as_array())
                .and_then(|p| p.first())
                .and_then(|p| p.get("rust"))
                .and_then(|r| r.as_str());
            match public {
                Some(r) => text.push_str(&format!(
                    "\n#[doc(hidden)]\npub use self::{r} as __lean_rust_model;\n"
                )),
                None => println!(
                    "cargo:warning=lean-rust: {}: lean/External.lean has no computable model to test it against",
                    m.rust
                ),
            }
            fs::write(&gen, &text)?;
            run_output(
                Command::new("rustfmt")
                    .args(["--edition", "2021"])
                    .arg(&gen),
                "rustfmt",
            )?;
            fs::write(cache.join(format!("{}.rs", m.key)), fs::read(&gen)?)?;
        }
        Ok(())
    }
}
