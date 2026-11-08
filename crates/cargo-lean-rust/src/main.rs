//! `cargo lean-rust`: verification of the `#[lean_rust::model]` functions of a crate.
//!
//! - `init` creates the crate's Lean package `lean/` requiring Aeneas and fetches Mathlib's
//!   build cache.
//! - `extract` translates the modelled functions with Charon and Aeneas into
//!   `lean/LeanRustGen/Model/`, writes the loop aliases, the obligations and the Rust externs,
//!   and records the extracted items in `lean-rust.lock`.
//! - `check` builds the package, checks the proofs of the obligations, records their states and
//!   writes the `@[csimp]` replacements of the proved `refines`.
//! - `status` prints the states (`--output json`).

mod check;
mod extract;

use lean_rust_build::model::{CrateItems, ModelFn, SpecRef};
use lean_rust_build::{Block, Builder, AENEAS_REV, LEAN_TOOLCHAIN};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

const USAGE: &str = "usage: cargo lean-rust <command> [options]

commands:
  init      Create the crate's Lean package lean/ (requiring Aeneas) and fetch Mathlib's cache
  extract   Translate the #[lean_rust::model] functions to Lean and state their obligations
  check     Build lean/, check the proofs of the obligations and record their states
  status    Print the states of the obligations

options:
  --manifest-path <Cargo.toml>   The crate (default: the package in the current directory)
  --packages-dir <dir>           init: Lake's packages directory, relative to lean/ (shared
                                 between packages; default: lean/.lake/packages)
  --no-cache                     init: do not run `lake exe cache get`
  --output json|text             status: the format (default: text)

environment: CHARON, AENEAS, LEAN_RUST_CLI (the executables; default from PATH), LAKE
";

pub struct Opts {
    pub manifest_path: Option<PathBuf>,
    pub packages_dir: Option<String>,
    pub no_cache: bool,
    pub json: bool,
}

/// The crate being verified.
pub struct Crate {
    pub dir: PathBuf,
    pub name: String,
    pub target_dir: PathBuf,
}

impl Crate {
    pub fn ident(&self) -> String {
        self.name.replace('-', "_")
    }

    pub fn lean_dir(&self) -> PathBuf {
        self.dir.join("lean")
    }

    pub fn builder(&self) -> Builder {
        Builder::with_dirs(
            &self.dir,
            self.target_dir.join("lean-rust").join("out"),
            &self.name,
        )
    }
}

pub fn tool(var: &str, default: &str) -> PathBuf {
    std::env::var_os(var)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(default))
}

/// Runs `cmd`; the error has its output.
pub fn run(cmd: &mut Command, what: &str) -> Result<String, String> {
    let out = cmd
        .output()
        .map_err(|e| format!("cannot run {what}: {e}"))?;
    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    if !out.status.success() {
        return Err(format!("{what} failed:\n{text}"));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn find_crate(opts: &Opts) -> Result<Crate, String> {
    let manifest = match &opts.manifest_path {
        Some(p) => p.clone(),
        None => {
            let mut dir = std::env::current_dir().map_err(|e| e.to_string())?;
            loop {
                let m = dir.join("Cargo.toml");
                if m.is_file()
                    && std::fs::read_to_string(&m)
                        .is_ok_and(|t| t.lines().any(|l| l.trim() == "[package]"))
                {
                    break m;
                }
                if !dir.pop() {
                    return Err(
                        "no Cargo.toml with a [package] in the current directory or its parents"
                            .into(),
                    );
                }
            }
        }
    };
    let manifest = manifest
        .canonicalize()
        .map_err(|e| format!("{}: {e}", manifest.display()))?;
    let text =
        std::fs::read_to_string(&manifest).map_err(|e| format!("{}: {e}", manifest.display()))?;
    let value: toml::Value =
        toml::from_str(&text).map_err(|e| format!("{}: {e}", manifest.display()))?;
    let name = value
        .get("package")
        .and_then(|p| p.get("name"))
        .and_then(|n| n.as_str())
        .ok_or_else(|| format!("{}: no package name", manifest.display()))?
        .to_string();
    let dir = manifest.parent().unwrap().to_path_buf();
    let meta = run(
        Command::new(tool("CARGO", "cargo"))
            .args([
                "metadata",
                "--no-deps",
                "--format-version",
                "1",
                "--manifest-path",
            ])
            .arg(&manifest),
        "cargo metadata",
    )?;
    let meta: serde_json::Value = serde_json::from_str(&meta).map_err(|e| e.to_string())?;
    let target_dir = meta
        .get("target_directory")
        .and_then(|t| t.as_str())
        .map(PathBuf::from)
        .unwrap_or_else(|| dir.join("target"));
    Ok(Crate {
        dir,
        name,
        target_dir,
    })
}

const STUB: &str = "module\n";

fn lakefile(c: &Crate, packages_dir: Option<&str>) -> String {
    let packages = packages_dir
        .map(|d| format!("packagesDir = \"{d}\"\n"))
        .unwrap_or_default();
    format!(
        "name = \"{}\"\ndefaultTargets = [\"LeanRustGen\", \"External\", \"ExternalTypes\", \"Proofs\"]\n{packages}\n\
         [[require]]\nname = \"aeneas\"\ngit = \"https://github.com/AeneasVerif/aeneas\"\nrev = \"{AENEAS_REV}\"\nsubDir = \"backends/lean\"\n\n\
         [[lean_lib]]\nname = \"LeanRustGen\"\nglobs = [\"LeanRustGen.+\"]\n\n\
         [[lean_lib]]\nname = \"External\"\n\n\
         [[lean_lib]]\nname = \"ExternalTypes\"\n\n\
         [[lean_lib]]\nname = \"Proofs\"\nglobs = [\"Proofs.+\"]\n",
        c.ident()
    )
}

fn init(c: &Crate, opts: &Opts) -> Result<(), String> {
    let lean = c.lean_dir();
    std::fs::create_dir_all(lean.join("Proofs")).map_err(|e| e.to_string())?;
    let lakefile_path = lean.join("lakefile.toml");
    match std::fs::read_to_string(&lakefile_path) {
        Ok(text) if text.contains("name = \"aeneas\"") => {
            println!("{} requires Aeneas already", lakefile_path.display());
        }
        Ok(text) if text.contains("[[require]]") || lean.join("lakefile.lean").exists() => {
            return Err(format!(
                "{} has other requirements; add `require aeneas` (rev {AENEAS_REV}, subDir backends/lean) and the libraries External, ExternalTypes and Proofs by hand",
                lakefile_path.display()
            ));
        }
        _ => {
            std::fs::write(&lakefile_path, lakefile(c, opts.packages_dir.as_deref()))
                .map_err(|e| e.to_string())?;
            println!("wrote {}", lakefile_path.display());
        }
    }
    std::fs::write(lean.join("lean-toolchain"), format!("{LEAN_TOOLCHAIN}\n"))
        .map_err(|e| e.to_string())?;
    let gitignore = lean.join(".gitignore");
    if !gitignore.exists() {
        std::fs::write(&gitignore, "/.lake/\n").map_err(|e| e.to_string())?;
    }
    for f in ["External.lean", "ExternalTypes.lean"] {
        let p = lean.join(f);
        if !p.exists() {
            std::fs::write(&p, STUB).map_err(|e| e.to_string())?;
        }
    }
    if !opts.no_cache {
        println!("lake exe cache get (Mathlib's build cache)");
        let status = Command::new(tool("LAKE", "lake"))
            .args(["exe", "cache", "get"])
            .current_dir(&lean)
            .status()
            .map_err(|e| format!("cannot run lake: {e}"))?;
        if !status.success() {
            return Err("lake exe cache get failed (it needs elan's leanprover/lean4 toolchain and a C compiler)".into());
        }
    }
    Ok(())
}

/// Checks that `lean/` is the package `init` creates.
pub fn check_package(c: &Crate) -> Result<(), String> {
    let lean = c.lean_dir();
    let lakefile = std::fs::read_to_string(lean.join("lakefile.toml")).map_err(|_| {
        format!(
            "{} has no lakefile.toml: run `cargo lean-rust init`",
            lean.display()
        )
    })?;
    for (needle, what) in [
        ("name = \"aeneas\"", "`require aeneas`"),
        (AENEAS_REV, &format!("the Aeneas rev {AENEAS_REV}") as &str),
        ("name = \"LeanRustGen\"", "`lean_lib LeanRustGen`"),
        ("name = \"Proofs\"", "`lean_lib Proofs`"),
    ] {
        if !lakefile.contains(needle) {
            return Err(format!(
                "{}/lakefile.toml lacks {what} (see `cargo lean-rust init`)",
                lean.display()
            ));
        }
    }
    let toolchain = std::fs::read_to_string(lean.join("lean-toolchain")).unwrap_or_default();
    if toolchain.trim() != LEAN_TOOLCHAIN {
        return Err(format!(
            "{}/lean-toolchain is `{}`; this lean-rust needs `{LEAN_TOOLCHAIN}`",
            lean.display(),
            toolchain.trim()
        ));
    }
    Ok(())
}

/// A spec resolved to Lean.
#[derive(Debug, Clone)]
pub struct Resolved {
    pub lean: String,
    pub boolean: bool,
    /// The module path of the `lean!` block, or the unit name of the generated function.
    pub block: String,
    pub key: String,
    /// The Lean module defining the spec.
    pub import: Option<String>,
}

/// The `lean!` blocks of the crate with their keys and the Lean names of their public functions.
pub struct Specs {
    pub blocks: Vec<Block>,
    pub keys: Vec<String>,
    pub cache: PathBuf,
}

fn exported_fns(file: &Path) -> Option<Vec<(String, String)>> {
    let text = std::fs::read_to_string(file).ok()?;
    let ast = syn::parse_file(&text).ok()?;
    let mut out = Vec::new();
    for item in &ast.items {
        let syn::Item::Fn(f) = item else { continue };
        for a in &f.attrs {
            if lean_rust_build::model::is_attr(a, "exported") {
                if let Ok(s) = a.parse_args::<syn::LitStr>() {
                    out.push((f.sig.ident.to_string(), s.value()));
                }
            }
        }
    }
    Some(out)
}

fn generated_module(file: &Path) -> Option<String> {
    let text = std::fs::read_to_string(file).ok()?;
    let first = text.lines().next()?;
    let rest = first.split(" from ").nth(1)?;
    Some(rest.trim_end_matches(". Do not edit.").to_string())
}

impl Specs {
    /// The cached module of block `i`: the one of its key, or another generated from the same
    /// Lean module (the names of the public functions do not depend on the key).
    fn cached_file(&self, i: usize, module: &str) -> Option<PathBuf> {
        let exact = self.cache.join(format!("{}.rs", self.keys[i]));
        if exact.is_file() {
            return Some(exact);
        }
        let header = format!(" from {module}. Do not edit.");
        std::fs::read_dir(&self.cache)
            .ok()?
            .flatten()
            .map(|e| e.path())
            .find(|p| {
                std::fs::read_to_string(p)
                    .is_ok_and(|t| t.lines().next().is_some_and(|l| l.ends_with(&header)))
            })
    }

    pub fn new(c: &Crate) -> Result<Specs, String> {
        let b = c.builder();
        let (blocks, _) = b.scan().map_err(|e| e.to_string())?;
        let keys = lean_rust_build::cache_keys(&c.name, &blocks, "").map_err(|e| e.to_string())?;
        Ok(Specs {
            blocks,
            keys,
            cache: b.cache_dir(),
        })
    }

    pub fn resolve(
        &self,
        c: &Crate,
        items: &CrateItems,
        f: &ModelFn,
        spec: &SpecRef,
    ) -> Result<Resolved, String> {
        let p = match spec {
            SpecRef::Lean(s) => {
                return Ok(Resolved {
                    lean: s.clone(),
                    boolean: false,
                    block: String::new(),
                    key: String::new(),
                    import: None,
                })
            }
            SpecRef::Path(p) => p,
        };
        let segs = items.resolve(&f.module, p);
        let at = format!("{}:{}", f.file, f.line);
        let shown = lean_rust_build::model::path_string(p);
        let Some((name, module)) = segs.split_last() else {
            return Err(format!("{at}: `{shown}` is not a function"));
        };
        if let Some(i) = self.blocks.iter().position(|b| b.path == module) {
            let b = &self.blocks[i];
            let file = self.cached_file(i, &b.lean_module(&c.ident()));
            let fns = file.as_deref().and_then(exported_fns).ok_or_else(|| {
                format!(
                    "{at}: the lean! block {} is not generated; build the crate (`cargo build`) first",
                    lean_rust_build::module_path_string(&b.path)
                )
            })?;
            let Some((_, lean)) = fns.iter().find(|(n, _)| n == name) else {
                return Err(format!(
                    "{at}: `{shown}` is not a public function of the lean! block {}",
                    lean_rust_build::module_path_string(&b.path)
                ));
            };
            return Ok(Resolved {
                lean: lean.clone(),
                boolean: true,
                block: lean_rust_build::module_path_string(&b.path),
                key: format!("sha256:{}", self.keys[i]),
                import: Some(b.lean_module(&c.ident())),
            });
        }
        let unit = lean_rust_build::module_path_string(&segs);
        if let Some((lean, file)) = items.exported.get(&unit) {
            return Ok(Resolved {
                lean: lean.clone(),
                boolean: true,
                block: unit.clone(),
                key: items.hashes.get(&unit).cloned().unwrap_or_default(),
                import: generated_module(&c.dir.join(file)),
            });
        }
        Err(format!(
            "{at}: `{shown}` ({unit}) is not a public function generated from Lean (by a lean! block or `lean-rust project generate`)"
        ))
    }
}

fn status(c: &Crate, opts: &Opts) -> Result<(), String> {
    let states = current_states(c)?;
    if opts.json {
        println!("{}", lean_rust_build::verify::json(&states));
    } else {
        print!("{}", lean_rust_build::verify::table(&states));
    }
    Ok(())
}

pub fn current_states(c: &Crate) -> Result<Vec<lean_rust_build::verify::ModelState>, String> {
    let b = c.builder();
    let items = b.scan_items().map_err(|e| e.to_string())?;
    let specs = Specs::new(c)?;
    let lock = lean_rust_build::lock::Lock::read(&b.lock_path())?;
    let keys = b
        .spec_hashes(&specs.blocks, &items)
        .map_err(|e| e.to_string())?;
    Ok(lean_rust_build::verify::states(
        &items,
        &lock,
        &keys,
        &c.ident(),
    ))
}

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().is_some_and(|a| a == "lean-rust") {
        args.remove(0);
    }
    let Some(cmd) = args.first().cloned() else {
        eprint!("{USAGE}");
        return ExitCode::from(2);
    };
    let mut opts = Opts {
        manifest_path: None,
        packages_dir: None,
        no_cache: false,
        json: false,
    };
    let mut it = args.into_iter().skip(1);
    while let Some(a) = it.next() {
        match a.as_str() {
            "--manifest-path" => opts.manifest_path = it.next().map(PathBuf::from),
            "--packages-dir" => opts.packages_dir = it.next(),
            "--no-cache" => opts.no_cache = true,
            "--output" => match it.next().as_deref() {
                Some("json") => opts.json = true,
                Some("text") => opts.json = false,
                _ => {
                    eprintln!("cargo lean-rust: --output takes json or text");
                    return ExitCode::from(2);
                }
            },
            _ => {
                eprintln!("cargo lean-rust: unknown option {a}\n{USAGE}");
                return ExitCode::from(2);
            }
        }
    }
    let result = match cmd.as_str() {
        "help" | "--help" | "-h" => {
            print!("{USAGE}");
            return ExitCode::SUCCESS;
        }
        "--version" => {
            println!("cargo-lean-rust {}", env!("CARGO_PKG_VERSION"));
            return ExitCode::SUCCESS;
        }
        "init" | "extract" | "check" | "status" => {
            find_crate(&opts).and_then(|c| match cmd.as_str() {
                "init" => init(&c, &opts),
                "extract" => extract::extract(&c),
                "check" => check::check(&c),
                _ => status(&c, &opts),
            })
        }
        _ => {
            eprint!("{USAGE}");
            return ExitCode::from(2);
        }
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("cargo lean-rust: {e}");
            ExitCode::FAILURE
        }
    }
}
