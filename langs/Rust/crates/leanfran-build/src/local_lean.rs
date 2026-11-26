use crate::{sha_hex, syntax::normalize_path, Error};
use sha2::{Digest, Sha256};
use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Path, PathBuf};

pub(super) fn packages_dir(root: &Path) -> Option<PathBuf> {
    let text = fs::read_to_string(root.join("lakefile.toml")).ok()?;
    let table: toml::Table = toml::from_str(&text).ok()?;
    root.join(table.get("packagesDir")?.as_str()?)
        .canonicalize()
        .ok()
}

pub(super) struct LocalLean<'a> {
    pub(super) root: &'a Path,
    pub(super) files: &'a [PathBuf],
    pub(super) modules: HashMap<PathBuf, (String, Vec<PathBuf>)>,
}

impl LocalLean<'_> {
    fn resolve(&self, import: &str) -> Option<PathBuf> {
        let path = module_path(&mut import.trim())?;
        self.files.iter().find(|f| f.ends_with(&path)).cloned()
    }

    pub(super) fn fingerprint(&mut self, imports: &[String]) -> Result<Option<String>, Error> {
        let mut pending: Vec<_> = imports.iter().filter_map(|m| self.resolve(m)).collect();
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
                    .filter_map(|p| self.files.iter().find(|f| f.ends_with(&p)).cloned())
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
        let lakefile = self.root.join("lakefile.toml");
        if self.files.contains(&lakefile) {
            hash.update(fs::read(&lakefile)?);
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
