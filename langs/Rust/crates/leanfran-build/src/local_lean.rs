use crate::{sha_hex, syntax::normalize_path, Error};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Path, PathBuf};

fn lakefile(root: &Path) -> Option<String> {
    // Lake prefers a Lean configuration when both files exist.
    if root.join("lakefile.lean").is_file() {
        return None;
    }
    fs::read_to_string(root.join("lakefile.toml")).ok()
}

pub(super) fn packages_dir(root: &Path) -> Option<PathBuf> {
    let text = lakefile(root)?;
    let table: toml::Table = toml::from_str(&text).ok()?;
    root.join(table.get("packagesDir")?.as_str()?)
        .canonicalize()
        .ok()
}

pub(super) struct LocalLean<'a> {
    root: &'a Path,
    files: &'a [PathBuf],
    packages: Vec<(PathBuf, Option<LakeConfig>)>,
    config_text: Option<String>,
    modules: HashMap<PathBuf, (String, Vec<PathBuf>)>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LakeConfig {
    #[serde(default)]
    src_dir: PathBuf,
    #[serde(default, rename = "lean_lib")]
    libs: Vec<Library>,
    #[serde(default, rename = "require")]
    requires: Vec<Requirement>,
}

#[derive(Deserialize)]
struct Requirement {
    path: Option<PathBuf>,
    source: Option<DependencySource>,
}

#[derive(Deserialize)]
struct DependencySource {
    #[serde(rename = "type")]
    kind: String,
    dir: Option<PathBuf>,
}

impl Requirement {
    fn path(&self) -> Option<&Path> {
        self.path.as_deref().or_else(|| {
            let source = self.source.as_ref()?;
            source.dir.as_deref().filter(|_| source.kind == "path")
        })
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Library {
    name: String,
    #[serde(default)]
    src_dir: PathBuf,
    roots: Option<Vec<String>>,
    globs: Option<Vec<String>>,
}

impl Library {
    fn builds(&self, path: &Path) -> bool {
        let roots = self
            .roots
            .as_deref()
            .unwrap_or(std::slice::from_ref(&self.name));
        let module = path.with_extension("");
        let Some(globs) = &self.globs else {
            return roots.iter().any(|root| {
                module_path(&mut root.as_str())
                    .is_some_and(|root| module.starts_with(root.with_extension("")))
            });
        };
        globs.iter().any(|glob| matches_glob(&module, glob))
            || roots.iter().any(|root| {
                let Some(root) = module_path(&mut root.as_str()).map(|p| p.with_extension(""))
                else {
                    return false;
                };
                module.starts_with(&root) && globs.iter().any(|glob| matches_glob(&root, glob))
            })
    }
}

fn matches_glob(module: &Path, glob: &str) -> bool {
    let (name, descendants, include_root) = if let Some(name) = glob.strip_suffix(".*") {
        (name, true, true)
    } else if let Some(name) = glob.strip_suffix(".+") {
        (name, true, false)
    } else {
        (glob, false, true)
    };
    let Some(root) = module_path(&mut name.trim()).map(|p| p.with_extension("")) else {
        return false;
    };
    if module == root {
        include_root
    } else {
        descendants && module.starts_with(root)
    }
}

impl<'a> LocalLean<'a> {
    pub(super) fn new(root: &'a Path, files: &'a [PathBuf]) -> Self {
        let toml = lakefile(root);
        let config: Option<LakeConfig> = toml.as_ref().and_then(|text| toml::from_str(text).ok());
        let config_text = toml.or_else(|| fs::read_to_string(root.join("lakefile.lean")).ok());
        let mut packages = vec![(root.to_path_buf(), config)];
        if let Ok(canonical_root) = root.canonicalize() {
            let mut visited = BTreeSet::from([root.to_path_buf()]);
            let mut i = 0;
            while let Some((dir, config)) = packages.get(i) {
                let deps: Vec<_> = config
                    .iter()
                    .flat_map(|cfg| cfg.requires.iter().rev())
                    .filter_map(Requirement::path)
                    .filter_map(|dep| {
                        let canonical = dir.join(dep).canonicalize().ok()?;
                        let dep = root.join(canonical.strip_prefix(&canonical_root).ok()?);
                        if !files.iter().any(|file| file.starts_with(&dep))
                            || !visited.insert(dep.clone())
                        {
                            return None;
                        }
                        let config = lakefile(&dep).and_then(|text| toml::from_str(&text).ok());
                        Some((dep, config))
                    })
                    .collect();
                packages.extend(deps);
                i += 1;
            }
        }
        Self {
            root,
            files,
            packages,
            config_text,
            modules: HashMap::new(),
        }
    }

    fn resolve(&self, path: &Path) -> Option<PathBuf> {
        for (package, config) in &self.packages {
            let Some(config) = config else {
                // Executable Lake configurations cannot be evaluated on an offline cache hit.
                if let Some(file) = self
                    .files
                    .iter()
                    .find(|f| f.starts_with(package) && f.ends_with(path))
                {
                    return Some(file.clone());
                }
                continue;
            };
            // Lake searches the workspace's own libraries in reverse declaration order.
            let Some(library) = config.libs.iter().rev().find(|lib| lib.builds(path)) else {
                continue;
            };
            let dir = package
                .join(&config.src_dir)
                .join(&library.src_dir)
                .canonicalize()
                .ok()?;
            let root = self.root.canonicalize().ok()?;
            let source = self.root.join(dir.strip_prefix(root).ok()?).join(path);
            return self
                .files
                .binary_search(&source)
                .ok()
                .map(|i| self.files[i].clone());
        }
        None
    }

    pub(super) fn fingerprint(&mut self, imports: &[String]) -> Result<Option<String>, Error> {
        let mut pending: Vec<_> = imports
            .iter()
            .filter_map(|m| module_path(&mut m.trim()).and_then(|p| self.resolve(&p)))
            .collect();
        if pending.is_empty() {
            return Ok(None);
        }
        let mut seen = BTreeSet::new();
        while let Some(path) = pending.pop() {
            if !seen.insert(path.clone()) {
                continue;
            }
            if !self.modules.contains_key(&path) {
                let source = fs::read_to_string(&path)
                    .map_err(|e| Error::new(format!("{}: {e}", path.display())))?;
                let deps = header_imports(&source)
                    .into_iter()
                    .filter_map(|p| self.resolve(&p))
                    .collect();
                let rel = normalize_path(path.strip_prefix(self.root).unwrap_or(&path));
                self.modules.insert(
                    path.clone(),
                    (sha_hex(&[rel.as_bytes(), source.as_bytes()]), deps),
                );
            }
            pending.extend(self.modules[&path].1.iter().cloned());
        }
        let mut hash = Sha256::new();
        for path in seen {
            hash.update(self.modules[&path].0.as_bytes());
        }
        if let Some(text) = &self.config_text {
            hash.update(text.as_bytes());
        }
        Ok(Some(
            hash.finalize().iter().map(|b| format!("{b:02x}")).collect(),
        ))
    }
}

fn skip_trivia(input: &mut &str) {
    loop {
        *input = input.trim_start();
        if let Some(rest) = input.strip_prefix("--") {
            *input = rest.split_once('\n').map_or("", |(_, rest)| rest);
        } else if let Some(rest) = input.strip_prefix("/-") {
            let mut depth = 1;
            *input = rest;
            while depth > 0 {
                let Some(i) = input
                    .as_bytes()
                    .windows(2)
                    .position(|p| p == b"/-" || p == b"-/")
                else {
                    *input = "";
                    return;
                };
                if input[i..].starts_with("/-") {
                    depth += 1;
                } else {
                    depth -= 1;
                }
                *input = &input[i + 2..];
            }
        } else {
            break;
        }
    }
}

fn keyword(input: &mut &str, word: &str) -> bool {
    match input.strip_prefix(word) {
        Some(rest)
            if rest.is_empty()
                || rest.starts_with(char::is_whitespace)
                || rest.starts_with("--")
                || rest.starts_with("/-") =>
        {
            *input = rest;
            skip_trivia(input);
            true
        }
        _ => false,
    }
}

fn module_path(input: &mut &str) -> Option<PathBuf> {
    let mut path = PathBuf::new();
    loop {
        let (part, rest) = if let Some(quoted) = input.strip_prefix('«') {
            quoted.split_once('»')?
        } else {
            let end = input
                .find(|c: char| c == '.' || c.is_whitespace() || c == '/' || c == '-')
                .unwrap_or(input.len());
            input.split_at(end)
        };
        if part.is_empty() || part == "." || part == ".." || part.contains(['/', '\\', ':']) {
            return None;
        }
        path.push(part);
        *input = rest;
        if let Some(next) = input.strip_prefix('.') {
            *input = next;
        } else {
            path.as_mut_os_string().push(".lean");
            return Some(path);
        }
    }
}

fn header_imports(mut input: &str) -> Vec<PathBuf> {
    skip_trivia(&mut input);
    keyword(&mut input, "module");
    let mut imports = Vec::new();
    if !keyword(&mut input, "prelude") {
        imports.push(PathBuf::from("Init.lean"));
    }
    loop {
        keyword(&mut input, "public");
        keyword(&mut input, "meta");
        if !keyword(&mut input, "import") {
            break;
        }
        keyword(&mut input, "all");
        let Some(path) = module_path(&mut input) else {
            break;
        };
        imports.push(path);
        skip_trivia(&mut input);
    }
    imports
}
