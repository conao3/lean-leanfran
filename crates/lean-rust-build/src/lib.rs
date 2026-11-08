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
//! Environment variables: `LEAN_RUST_CLI` (the `lean-rust` executable, default from `PATH`),
//! `LEAN_RUST_OFFLINE=1` (use the cache only), `LEAN_RUST_EXTRACTING=1` (do nothing).

pub mod syntax;

use sha2::{Digest, Sha256};
use std::collections::{BTreeSet, HashMap};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use syn::visit::Visit;
use syntax::{file_hash, normalize_path, LeanBlock};

/// Version of the generator: the `lean-rust --version` this crate works with, and part of every
/// cache key.
pub const GENERATOR_VERSION: &str = "0.1.0";

/// The Lean toolchain of the crate's Lean package (`lean/lean-toolchain`).
pub const LEAN_TOOLCHAIN: &str = "leanprover/lean4:v4.35.0";

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

    fn crate_ident(&self) -> String {
        self.crate_name.replace('-', "_")
    }

    fn cache_dir(&self) -> PathBuf {
        self.manifest_dir.join(".lean-rust").join("cache")
    }

    fn lean_dir(&self) -> PathBuf {
        self.manifest_dir.join("lean")
    }

    /// Generates the Rust modules of all `lean!` blocks of the crate into `OUT_DIR`.
    pub fn compile(&self) -> Result<(), Error> {
        println!("cargo:rerun-if-env-changed=LEAN_RUST_EXTRACTING");
        println!("cargo:rerun-if-env-changed=LEAN_RUST_OFFLINE");
        println!("cargo:rerun-if-env-changed=LEAN_RUST_CLI");
        if std::env::var("LEAN_RUST_EXTRACTING").as_deref() == Ok("1") {
            return Ok(());
        }
        let (blocks, files) = self.scan()?;
        for f in &files {
            println!("cargo:rerun-if-changed={}", f.display());
        }
        let src = self.manifest_dir.join("src");
        if src.is_dir() {
            println!("cargo:rerun-if-changed={}", src.display());
        }
        let keys = cache_keys(&self.crate_name, &blocks)?;
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
        if !missing.is_empty() {
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
        let cli = std::env::var_os("LEAN_RUST_CLI")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("lean-rust"));
        let version = run_output(
            Command::new(&cli).arg("--version"),
            &cli.display().to_string(),
        )?;
        if version.trim() != format!("lean-rust {GENERATOR_VERSION}") {
            return Err(Error::new(format!(
                "lean-rust-build: {} is `{}`; this build needs `lean-rust {GENERATOR_VERSION}`",
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
        prune_dir(
            &lean.join("LeanRustGen").join("Embed").join(&crate_ident),
            &blocks
                .iter()
                .map(|b| lean.join(b.lean_file(&crate_ident)))
                .collect(),
        )?;
        let modules: Vec<String> = missing
            .iter()
            .map(|&i| blocks[i].lean_module(&crate_ident))
            .collect();
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
                serde_json::json!({
                    "module": blocks[i].lean_module(&crate_ident),
                    "namespace": blocks[i].name,
                    "output_file": tmp.join(format!("{}.rs", keys[i])).to_string_lossy(),
                })
            })
            .collect();
        let batch = tmp.join("batch.json");
        fs::write(&batch, serde_json::Value::Array(jobs).to_string())?;
        let mut cmd = Command::new(&cli);
        cmd.args(["module", "generate", "--batch"])
            .arg(&batch)
            .args(["--output", "json", "--search-path"]);
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
        let live: BTreeSet<PathBuf> = keys.iter().map(|k| cache.join(format!("{k}.rs"))).collect();
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

/// Module path of a file relative to the crate root: `src/a/b.rs` and `src/a/b/mod.rs` →
/// `[a, b]`; `src/lib.rs`, `src/main.rs` and `src/bin/*.rs` are crate roots.
fn file_module(rel: &str) -> Vec<String> {
    let rest = rel.strip_prefix("src/").unwrap_or(rel);
    if rest == "lib.rs" || rest == "main.rs" || rest.starts_with("bin/") {
        return Vec::new();
    }
    let mut parts: Vec<String> = rest
        .trim_end_matches(".rs")
        .split('/')
        .map(str::to_string)
        .collect();
    if parts.last().is_some_and(|p| p == "mod") {
        parts.pop();
    }
    parts
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

fn module_path_string(path: &[String]) -> String {
    let mut s = String::from("crate");
    for p in path {
        s.push_str("::");
        s.push_str(p);
    }
    s
}

/// The cache key of every block: SHA-256 over the crate name, the file, the block name, the
/// imports, the source, the keys of the used blocks and [`GENERATOR_VERSION`].
pub fn cache_keys(crate_name: &str, blocks: &[Block]) -> Result<Vec<String>, Error> {
    let index: HashMap<&[String], usize> = blocks
        .iter()
        .enumerate()
        .map(|(i, b)| (b.path.as_slice(), i))
        .collect();
    let mut keys: Vec<Option<String>> = vec![None; blocks.len()];
    fn key_of(
        i: usize,
        crate_name: &str,
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
        for u in &b.uses {
            let Some(&j) = index.get(u.as_slice()) else {
                return Err(Error::new(format!(
                    "lean-rust-build: {}: `uses` names {}, which is not a lean! block of this crate",
                    b.file,
                    module_path_string(u)
                )));
            };
            h.update(key_of(j, crate_name, blocks, index, keys, stack)?.as_bytes());
            h.update([1]);
        }
        h.update([0]);
        h.update(GENERATOR_VERSION.as_bytes());
        stack.pop();
        let k: String = h.finalize().iter().map(|b| format!("{b:02x}")).collect();
        keys[i] = Some(k.clone());
        Ok(k)
    }
    let mut stack = Vec::new();
    (0..blocks.len())
        .map(|i| key_of(i, crate_name, blocks, &index, &mut keys, &mut stack))
        .collect()
}

/// The Lean file of a block, the number of lines before the source and the indentation
/// removed from the source.
pub fn lean_source(b: &Block, used: &[&Block], crate_ident: &str) -> (String, usize, usize) {
    let mut text = String::new();
    for imp in &b.imports {
        text.push_str(&format!("import {imp}\n"));
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
