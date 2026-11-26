use crate::{collect_user_files, sha_hex, syntax::normalize_path, Error};
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
    files: Vec<PathBuf>,
    packages: Vec<(PathBuf, Option<LakeConfig>)>,
    copied_dirs: Vec<(PathBuf, PathBuf)>,
    overrides_present: bool,
    config_hashes: Vec<String>,
    fallback_fingerprint: Option<String>,
    modules: HashMap<PathBuf, (String, Vec<PathBuf>)>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LakeConfig {
    #[serde(default)]
    src_dir: PathBuf,
    lake_dir: Option<PathBuf>,
    #[serde(default, rename = "lean_lib")]
    libs: Vec<Library>,
    #[serde(default, rename = "require")]
    requires: Vec<Requirement>,
}

#[derive(Deserialize)]
struct Requirement {
    name: String,
    path: Option<PathBuf>,
    source: Option<DependencySource>,
}

#[derive(Deserialize)]
struct DependencySource {
    #[serde(rename = "type")]
    kind: String,
    dir: Option<PathBuf>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LakeManifest {
    packages_dir: Option<PathBuf>,
    lake_dir: Option<PathBuf>,
    packages: Vec<LockedPackage>,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum LockedPackage {
    Git {
        name: String,
        url: String,
    },
    #[serde(rename_all = "camelCase")]
    Path {
        name: String,
        dir: PathBuf,
        #[serde(default)]
        copy: bool,
        config_file: Option<PathBuf>,
        manifest_file: Option<PathBuf>,
    },
    #[serde(other)]
    Other,
}

impl LockedPackage {
    fn name(&self) -> Option<&str> {
        match self {
            Self::Git { name, .. } | Self::Path { name, .. } => Some(name),
            Self::Other => None,
        }
    }
}

fn reachable_paths<'a>(
    root: Option<&'a LakeConfig>,
    configs: impl IntoIterator<Item = (&'a str, Option<&'a LakeConfig>)>,
) -> Option<BTreeSet<&'a str>> {
    let configs: HashMap<_, _> = configs.into_iter().collect();
    let mut visited = BTreeSet::new();
    let mut pending = vec![root?];
    while let Some(config) = pending.pop() {
        for require in &config.requires {
            if visited.insert(require.name.as_str()) {
                pending.push(configs.get(require.name.as_str()).copied().flatten()?);
            }
        }
    }
    Some(visited)
}

fn is_local_git_url(url: &str) -> bool {
    url.starts_with("file://") || Path::new(url).is_absolute() || !url.contains(':')
}

fn package_dir_name(mut name: &str) -> String {
    let mut dir = String::new();
    while let Some((prefix, rest)) = name.split_once('«') {
        let Some((component, suffix)) = rest.split_once('»') else {
            break;
        };
        dir.push_str(prefix);
        dir.push_str(component);
        name = suffix;
    }
    dir.push_str(name);
    dir
}

fn rebase_copied_path(
    mut path: PathBuf,
    copies: &[(PathBuf, PathBuf)],
    missing_only: bool,
) -> PathBuf {
    for _ in copies {
        let Some(source) = copies.iter().find_map(|(copy, source)| {
            let relative = path.strip_prefix(copy).ok()?;
            (!missing_only || !copy.is_dir()).then(|| source.join(relative))
        }) else {
            break;
        };
        path = source;
    }
    path
}

fn hash_config(
    root: &Path,
    file: &Path,
    identity: &Path,
    hashes: &mut Vec<String>,
) -> Option<String> {
    let text = fs::read_to_string(file).ok()?;
    let relative = normalize_path(identity.strip_prefix(root).unwrap_or(identity));
    hashes.push(sha_hex(&[relative.as_bytes(), text.as_bytes()]));
    Some(text)
}

fn package_config(
    root: &Path,
    dir: &Path,
    identity: &Path,
    file: Option<PathBuf>,
    hashes: &mut Vec<String>,
) -> Option<LakeConfig> {
    let file = file.unwrap_or_else(|| {
        if dir.join("lakefile.lean").is_file() {
            PathBuf::from("lakefile.lean")
        } else {
            PathBuf::from("lakefile.toml")
        }
    });
    let text = hash_config(root, &dir.join(&file), &identity.join(&file), hashes)?;
    if file.extension().is_some_and(|ext| ext == "toml") {
        toml::from_str(&text).ok()
    } else {
        None
    }
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
    pub(super) fn new(root: &'a Path, mut files: Vec<PathBuf>) -> Self {
        let mut config_hashes = Vec::new();
        let config = package_config(root, root, root, None, &mut config_hashes);
        let mut packages = vec![(root.to_path_buf(), config)];
        let manifest_file = root.join("lake-manifest.json");
        let manifest = hash_config(root, &manifest_file, &manifest_file, &mut config_hashes);
        let manifest_hash = config_hashes.last().cloned();
        let mut fallback_fingerprint = None;
        let mut copied_dirs = Vec::new();
        let mut extra_files = Vec::new();
        let mut overrides_present = false;
        if let Ok(canonical_root) = root.canonicalize() {
            let mut visited = BTreeSet::from([root.to_path_buf()]);
            let mut local_dir = |path: PathBuf| {
                let canonical = path.canonicalize().ok()?;
                let dep = root.join(canonical.strip_prefix(&canonical_root).ok()?);
                (files.iter().any(|file| file.starts_with(&dep)) && visited.insert(dep.clone()))
                    .then_some(dep)
            };
            if let Some(manifest) = manifest {
                if let Ok(mut manifest) = serde_json::from_str::<LakeManifest>(&manifest) {
                    let lake_dir = packages[0]
                        .1
                        .as_ref()
                        .and_then(|cfg| cfg.lake_dir.as_deref())
                        .or(manifest.lake_dir.as_deref())
                        .unwrap_or(Path::new(".lake"));
                    let overrides = root.join(lake_dir).join("package-overrides.json");
                    overrides_present = !matches!(overrides.try_exists(), Ok(false));
                    if let Some(text) =
                        hash_config(root, &overrides, &overrides, &mut config_hashes)
                    {
                        extra_files.push(overrides);
                        fallback_fingerprint = config_hashes.last().cloned();
                        if let Ok(overrides) = serde_json::from_str::<LakeManifest>(&text) {
                            for entry in overrides.packages {
                                if let Some(name) = entry.name() {
                                    manifest
                                        .packages
                                        .retain(|locked| locked.name() != Some(name));
                                    manifest.packages.push(entry);
                                }
                            }
                        }
                    }
                    if manifest.packages.iter().any(
                        |entry| matches!(entry, LockedPackage::Git { url, .. } if is_local_git_url(url)),
                    ) {
                        fallback_fingerprint = match (manifest_hash, fallback_fingerprint) {
                            (Some(manifest), Some(overrides)) => {
                                Some(sha_hex(&[manifest.as_bytes(), overrides.as_bytes()]))
                            }
                            (manifest, overrides) => manifest.or(overrides),
                        };
                    }
                    let packages_dir = root.join(
                        manifest
                            .packages_dir
                            .unwrap_or_else(|| lake_dir.join("packages")),
                    );
                    let copies: Vec<_> = manifest
                        .packages
                        .iter()
                        .filter_map(|entry| match entry {
                            LockedPackage::Path {
                                name,
                                dir,
                                copy: true,
                                ..
                            } => Some((packages_dir.join(package_dir_name(name)), root.join(dir))),
                            _ => None,
                        })
                        .collect();
                    let mut locked = Vec::new();
                    for entry in manifest.packages {
                        if let LockedPackage::Path {
                            name,
                            dir,
                            copy,
                            config_file,
                            manifest_file,
                        } = entry
                        {
                            let source = root.join(dir);
                            let identity = rebase_copied_path(source.clone(), &copies, false);
                            let (dir, identity) = if copy || source != identity {
                                let materialized = if copy {
                                    packages_dir.join(package_dir_name(&name))
                                } else {
                                    source
                                };
                                let dir = rebase_copied_path(materialized, &copies, true);
                                let nested_packages = self::packages_dir(&dir);
                                collect_user_files(
                                    &dir,
                                    &dir,
                                    nested_packages.as_deref(),
                                    false,
                                    &mut extra_files,
                                );
                                copied_dirs.push((dir.clone(), identity.clone()));
                                (dir, identity)
                            } else {
                                let Some(dir) = local_dir(source) else {
                                    continue;
                                };
                                (dir.clone(), dir)
                            };
                            let mut hashes = Vec::new();
                            let config =
                                package_config(root, &dir, &identity, config_file, &mut hashes);
                            if let Some(manifest_file) = manifest_file {
                                hash_config(
                                    root,
                                    &dir.join(&manifest_file),
                                    &identity.join(&manifest_file),
                                    &mut hashes,
                                );
                            }
                            locked.push((name, dir, config, hashes));
                        }
                    }
                    // Overrides can change the requirements of the locked packages.
                    let reachable = if !overrides_present {
                        reachable_paths(
                            packages[0].1.as_ref(),
                            locked
                                .iter()
                                .map(|(name, _, config, _)| (name.as_str(), config.as_ref())),
                        )
                    } else {
                        None
                    };
                    let active: Vec<_> = locked
                        .iter()
                        .map(|(name, ..)| {
                            reachable
                                .as_ref()
                                .is_none_or(|set| set.contains(name.as_str()))
                        })
                        .collect();
                    for ((_, dir, config, hashes), active) in locked.into_iter().zip(active) {
                        if active {
                            packages.push((dir, config));
                            config_hashes.extend(hashes);
                        }
                    }
                }
            } else {
                // Before the first Lake build, use the declared paths until Lake writes its lock.
                let mut i = 0;
                while let Some((dir, config)) = packages.get(i) {
                    let deps: Vec<_> = config
                        .iter()
                        .flat_map(|cfg| cfg.requires.iter().rev())
                        .filter_map(Requirement::path)
                        .filter_map(|dep| {
                            let dep = local_dir(dir.join(dep))?;
                            let config = package_config(root, &dep, &dep, None, &mut config_hashes);
                            let manifest = dep.join("lake-manifest.json");
                            hash_config(root, &manifest, &manifest, &mut config_hashes);
                            Some((dep, config))
                        })
                        .collect();
                    packages.extend(deps);
                    i += 1;
                }
            }
        }
        files.extend(extra_files);
        files.sort();
        files.dedup();
        Self {
            root,
            files,
            packages,
            copied_dirs,
            overrides_present,
            config_hashes,
            fallback_fingerprint,
            modules: HashMap::new(),
        }
    }

    pub(super) fn files(&self) -> &[PathBuf] {
        &self.files
    }

    fn resolve(&self, path: &Path) -> impl Iterator<Item = PathBuf> + '_ {
        let path = path.to_path_buf();
        self.packages
            .iter()
            .filter_map(move |(package, config)| {
                let Some(config) = config else {
                    // Executable Lake configurations cannot be evaluated on an offline cache hit.
                    return self
                        .files
                        .iter()
                        .find(|f| f.starts_with(package) && f.ends_with(&path))
                        .cloned();
                };
                // Lake searches the workspace's own libraries in reverse declaration order.
                let library = config.libs.iter().rev().find(|lib| lib.builds(&path))?;
                let dir = package.join(&config.src_dir).join(&library.src_dir);
                // The file scan keeps the path through symlinks, even for targets outside lean/.
                let source = dir.join(&path);
                if self.files.binary_search(&source).is_ok() {
                    return Some(source);
                }
                let dir = dir.canonicalize().ok()?;
                let root = self.root.canonicalize().ok()?;
                let source = self.root.join(dir.strip_prefix(root).ok()?).join(&path);
                self.files
                    .binary_search(&source)
                    .ok()
                    .map(|i| self.files[i].clone())
            })
            .take(if self.overrides_present {
                usize::MAX
            } else {
                1
            })
    }

    pub(super) fn fingerprint(&mut self, imports: &[String]) -> Result<Option<String>, Error> {
        let mut pending: Vec<_> = imports
            .iter()
            .filter_map(|m| module_path(&mut m.trim()))
            .flat_map(|p| self.resolve(&p))
            .collect();
        if pending.is_empty() {
            return Ok(if imports.is_empty() {
                None
            } else {
                self.fallback_fingerprint.clone()
            });
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
                    .flat_map(|p| self.resolve(&p))
                    .collect();
                let identity = self.copied_dirs.iter().find_map(|(dir, identity)| {
                    path.strip_prefix(dir).ok().map(|p| identity.join(p))
                });
                let identity = identity.as_deref().unwrap_or(&path);
                let rel = normalize_path(identity.strip_prefix(self.root).unwrap_or(identity));
                self.modules.insert(
                    path.clone(),
                    (sha_hex(&[rel.as_bytes(), source.as_bytes()]), deps),
                );
            }
            pending.extend(self.modules[&path].1.iter().cloned());
        }
        let mut hash = Sha256::new();
        let mut modules: Vec<_> = seen.into_iter().collect();
        if !self.copied_dirs.is_empty() {
            modules.sort_by_key(|path| &self.modules[path].0);
        }
        for path in modules {
            hash.update(self.modules[&path].0.as_bytes());
        }
        for config in &self.config_hashes {
            hash.update(config.as_bytes());
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
