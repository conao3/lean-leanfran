//! Lean files generated from Aeneas's model: the aliases of the loops, the obligations, the
//! functions calling the Rust functions (`rs:` externs) and the `@[csimp]` replacements.

use crate::model::{LoopNode, Mode, ModelFn};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write;

/// A line and a column.
pub type Pos = (usize, usize);

/// A declaration of Aeneas's output.
#[derive(Debug, Clone)]
pub struct AeneasDecl {
    /// The Lean name relative to the model namespace (`inv.total_loop`).
    pub lean: String,
    /// The Rust path of the docstring (`probe::inv::total`).
    pub rust: Option<String>,
    /// `loop N` of the docstring.
    pub loop_index: Option<usize>,
    /// `Source:` file, start and end (line, column).
    pub source: Option<(String, Pos, Pos)>,
    /// The text after the docstring.
    pub body: String,
}

const DECL_KEYWORDS: &[&str] = &[
    "def",
    "structure",
    "inductive",
    "axiom",
    "abbrev",
    "opaque",
    "theorem",
    "class",
    "instance",
];

fn parse_pos(s: &str) -> Option<(usize, usize)> {
    let (l, c) = s.split_once(':')?;
    Some((l.trim().parse().ok()?, c.trim().parse().ok()?))
}

fn decl_name(body: &str) -> Option<String> {
    let mut text = body.trim_start();
    loop {
        if let Some(rest) = text.strip_prefix("@[") {
            let mut depth = 1;
            let mut end = None;
            for (i, ch) in rest.char_indices() {
                match ch {
                    '[' => depth += 1,
                    ']' => {
                        depth -= 1;
                        if depth == 0 {
                            end = Some(i);
                            break;
                        }
                    }
                    _ => {}
                }
            }
            text = rest[end? + 1..].trim_start();
            continue;
        }
        let mut words = text.split_whitespace();
        let first = words.next()?;
        if [
            "noncomputable",
            "private",
            "protected",
            "partial",
            "unsafe",
            "public",
        ]
        .contains(&first)
        {
            text = text[first.len()..].trim_start();
            continue;
        }
        if DECL_KEYWORDS.contains(&first) {
            return words.next().map(str::to_string);
        }
        return None;
    }
}

/// The declarations of a file of Aeneas's output (`Funs.lean`, `Types.lean`), in order.
pub fn parse_aeneas(text: &str) -> Vec<AeneasDecl> {
    let mut out = Vec::new();
    let chunks: Vec<&str> = text.split("/--").collect();
    for chunk in chunks.iter().skip(1) {
        let Some((doc, body)) = chunk.split_once("-/") else {
            continue;
        };
        let Some(lean) = decl_name(body) else {
            continue;
        };
        let doc = doc.trim();
        let mut rust = None;
        let mut loop_index = None;
        if let Some(rest) = doc.strip_prefix('[') {
            let mut depth = 1;
            let mut end = 0;
            for (i, ch) in rest.char_indices() {
                match ch {
                    '[' => depth += 1,
                    ']' => {
                        depth -= 1;
                        if depth == 0 {
                            end = i;
                            break;
                        }
                    }
                    _ => {}
                }
            }
            rust = Some(rest[..end].to_string());
            let after = &rest[end + 1..];
            if let Some(l) = after.trim_start_matches(':').trim().strip_prefix("loop ") {
                loop_index = l
                    .split(|c: char| !c.is_ascii_digit())
                    .next()
                    .and_then(|n| n.parse().ok());
            }
        }
        let source = doc.lines().find_map(|l| {
            let l = l.trim().strip_prefix("Source: '")?;
            let (file, rest) = l.split_once('\'')?;
            let range = rest
                .trim()
                .trim_start_matches(',')
                .trim()
                .strip_prefix("lines ")?;
            let (a, b) = range.split_once('-')?;
            Some((file.to_string(), parse_pos(a)?, parse_pos(b)?))
        });
        let end = body.find("\nend ").unwrap_or(body.len());
        out.push(AeneasDecl {
            lean,
            rust,
            loop_index,
            source,
            body: body[..end].to_string(),
        });
    }
    out
}

/// The unit name (see [`crate::model::ModelFn::rust`]) of a Rust path of Aeneas's docstrings:
/// `probe::inv::{probe::inv::Item}::new` → `crate::inv::Item::new`,
/// `probe::inv::{impl probe::inv::Weigh for probe::inv::Item}::weight` →
/// `crate::inv::<Item as Weigh>::weight`. `None` for paths outside the crate.
pub fn aeneas_unit(path: &str, crate_ident: &str) -> Option<String> {
    let rest = path.strip_prefix(crate_ident)?.strip_prefix("::")?;
    let last = |s: &str| -> String {
        let s = s.split('<').next().unwrap_or(s).trim();
        s.rsplit("::").next().unwrap_or(s).to_string()
    };
    if let Some(open) = rest.find('{') {
        let close = rest[open..].find('}')? + open;
        let module = rest[..open].trim_end_matches("::");
        let inner = &rest[open + 1..close];
        let after = rest[close + 1..].strip_prefix("::")?;
        if after.contains('{') {
            return None;
        }
        let mut s = String::from("crate");
        if !module.is_empty() {
            s.push_str("::");
            s.push_str(module);
        }
        if let Some(imp) = inner.strip_prefix("impl ") {
            let (tr, ty) = imp.split_once(" for ")?;
            s.push_str(&format!("::<{} as {}>::{after}", last(ty), last(tr)));
        } else {
            s.push_str(&format!("::{}::{after}", last(inner)));
        }
        Some(s)
    } else {
        Some(format!("crate::{rest}"))
    }
}

const LEAN_KEYWORDS: &[&str] = &[
    "at",
    "by",
    "do",
    "else",
    "end",
    "fun",
    "have",
    "if",
    "in",
    "let",
    "match",
    "then",
    "with",
    "show",
    "from",
    "where",
    "def",
    "theorem",
    "open",
    "import",
    "namespace",
    "section",
    "for",
    "unless",
    "return",
    "mut",
    "deriving",
    "instance",
    "structure",
    "class",
    "inductive",
    "variable",
    "universe",
    "example",
    "abbrev",
    "axiom",
    "local",
    "true",
    "false",
];

/// A Lean identifier for `s`, quoted with `«»` when it is a keyword.
pub fn lean_ident(s: &str) -> String {
    if LEAN_KEYWORDS.contains(&s) {
        format!("«{s}»")
    } else {
        s.to_string()
    }
}

/// The names reserved below a model name.
pub const RESERVED_LABELS: &[&str] = &["obligation", "proof", "rs", "impl", "csimp", "spec"];

/// Lean identifiers of `text`.
fn identifiers(text: &str) -> BTreeSet<String> {
    let mut out = BTreeSet::new();
    let mut cur = String::new();
    let mut quoted = false;
    for c in text.chars() {
        if quoted {
            cur.push(c);
            if c == '»' {
                quoted = false;
            }
            continue;
        }
        if c == '«' {
            cur.push(c);
            quoted = true;
        } else if c.is_alphanumeric() || c == '_' || c == '.' || c == '\'' {
            cur.push(c);
        } else if !cur.is_empty() {
            out.insert(std::mem::take(&mut cur));
        }
    }
    if !cur.is_empty() {
        out.insert(cur);
    }
    out
}

/// The units of the crate the model of `root` (a Lean name) depends on: the declarations it
/// refers to, transitively, with their Rust paths.
pub fn reachable_units(decls: &[AeneasDecl], root: &str, crate_ident: &str) -> BTreeSet<String> {
    let by_name: BTreeMap<&str, &AeneasDecl> = decls.iter().map(|d| (d.lean.as_str(), d)).collect();
    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut stack = vec![root];
    let mut units = BTreeSet::new();
    while let Some(n) = stack.pop() {
        if !seen.insert(n) {
            continue;
        }
        let Some(d) = by_name.get(n) else { continue };
        if let Some(u) = d.rust.as_deref().and_then(|r| aeneas_unit(r, crate_ident)) {
            units.insert(u);
        }
        for id in identifiers(&d.body) {
            let mut cand = id.as_str();
            loop {
                if let Some((k, _)) = by_name.get_key_value(cand) {
                    stack.push(k);
                    break;
                }
                match cand.rfind('.') {
                    Some(i) => cand = &cand[..i],
                    None => break,
                }
            }
        }
    }
    units
}

/* Loops */

#[derive(Debug, Clone, PartialEq)]
struct AeneasLoop {
    name: String,
    path: Vec<usize>,
    end: Option<(usize, usize)>,
    file: Option<String>,
}

/// The loops of the model `lean` (`<f>_loop`, `<f>_loop0`, `<f>_loop1_loop0`, …) with their
/// position paths.
fn aeneas_loops(decls: &[AeneasDecl], lean: &str) -> Vec<AeneasLoop> {
    let mut out = Vec::new();
    for d in decls {
        if d.loop_index.is_none() {
            continue;
        }
        let Some(suffix) = d.lean.strip_prefix(lean) else {
            continue;
        };
        let path = if suffix == "_loop" {
            Some(vec![0])
        } else {
            let mut path = Vec::new();
            let mut ok = !suffix.is_empty();
            for part in suffix.split("_loop").skip(1) {
                match part.parse::<usize>() {
                    Ok(n) => path.push(n),
                    Err(_) => ok = false,
                }
            }
            if suffix.split("_loop").next() != Some("") {
                ok = false;
            }
            ok.then_some(path)
        };
        if let Some(path) = path {
            out.push(AeneasLoop {
                name: d.lean.clone(),
                path,
                end: d.source.as_ref().map(|s| s.2),
                file: d.source.as_ref().map(|s| s.0.clone()),
            });
        }
    }
    out.sort_by(|a, b| a.path.cmp(&b.path));
    out
}

fn show_rust_tree(nodes: &[LoopNode], depth: usize, out: &mut String) {
    for n in nodes {
        match n {
            LoopNode::Loop {
                label,
                line,
                children,
                ..
            } => {
                let l = label
                    .as_deref()
                    .map(|l| format!("'{l}"))
                    .unwrap_or("(no label)".into());
                let _ = writeln!(out, "{}{l} (line {line})", "  ".repeat(depth + 1));
                show_rust_tree(children, depth + 1, out);
            }
            LoopNode::Macro { start, .. } => {
                let _ = writeln!(
                    out,
                    "{}macro call (line {})",
                    "  ".repeat(depth + 1),
                    start.0
                );
            }
        }
    }
}

fn in_span(p: (usize, usize), start: (usize, usize), end: (usize, usize)) -> bool {
    p >= start && p <= end
}

fn macro_spans(nodes: &[LoopNode], out: &mut Vec<(Pos, Pos)>) {
    for n in nodes {
        match n {
            LoopNode::Macro { start, end } => out.push((*start, *end)),
            LoopNode::Loop { children, .. } => macro_spans(children, out),
        }
    }
}

/// Matches the Rust loops (without macro calls) with the Aeneas loops at `prefix`.
fn match_loops(
    nodes: &[LoopNode],
    loops: &[AeneasLoop],
    prefix: &[usize],
    labels: &mut Vec<String>,
    out: &mut Vec<(Vec<String>, String)>,
) -> bool {
    let rust: Vec<&LoopNode> = nodes
        .iter()
        .filter(|n| matches!(n, LoopNode::Loop { .. }))
        .collect();
    let mut children: Vec<&AeneasLoop> = loops
        .iter()
        .filter(|l| l.path.len() == prefix.len() + 1 && l.path.starts_with(prefix))
        .collect();
    children.sort_by_key(|l| l.path[prefix.len()]);
    if rust.len() != children.len() {
        return false;
    }
    for (r, a) in rust.iter().zip(children) {
        let LoopNode::Loop {
            label,
            children: rc,
            ..
        } = r
        else {
            continue;
        };
        labels.push(label.clone().unwrap_or_default());
        out.push((labels.clone(), a.name.clone()));
        let ok = match_loops(rc, loops, &a.path, labels, out);
        labels.pop();
        if !ok {
            return false;
        }
    }
    true
}

/// The aliases of the loops of `f` (model `lean`): label paths and Aeneas names.
pub fn loop_aliases(
    f: &ModelFn,
    decls: &[AeneasDecl],
    lean: &str,
) -> Result<Vec<(Vec<String>, String)>, String> {
    fn unlabeled(nodes: &[LoopNode]) -> Option<(usize, usize)> {
        for n in nodes {
            if let LoopNode::Loop {
                label,
                line,
                column,
                children,
            } = n
            {
                if label.is_none() {
                    return Some((*line, *column));
                }
                if let Some(p) = unlabeled(children) {
                    return Some(p);
                }
            }
        }
        None
    }
    if let Some((line, col)) = unlabeled(&f.loops) {
        return Err(format!(
            "{}:{line}:{col}: a loop of the modelled function {} has no label; add one (`'name: for ..`) to name it in Lean",
            f.file, f.rust
        ));
    }
    let mut spans = Vec::new();
    macro_spans(&f.loops, &mut spans);
    let all = aeneas_loops(decls, lean);
    let in_macro: Vec<&AeneasLoop> = all
        .iter()
        .filter(|l| {
            l.file
                .as_deref()
                .is_some_and(|x| x == f.file || x.ends_with(&format!("/{}", f.file)))
                && l.end
                    .is_some_and(|e| spans.iter().any(|(s, t)| in_span(e, *s, *t)))
        })
        .collect();
    let loops: Vec<AeneasLoop> = all
        .iter()
        .filter(|l| !in_macro.iter().any(|m| l.path.starts_with(&m.path)))
        .cloned()
        .collect();
    let mut out = Vec::new();
    if !match_loops(&f.loops, &loops, &[], &mut Vec::new(), &mut out) || out.len() != loops.len() {
        let mut rust = String::new();
        show_rust_tree(&f.loops, 0, &mut rust);
        let mut lean_tree = String::new();
        for l in &all {
            let _ = writeln!(lean_tree, "{}{}", "  ".repeat(l.path.len()), l.name);
        }
        return Err(format!(
            "{}:{}: the loops of {} do not match its Lean model\n  Rust:\n{rust}  Aeneas:\n{lean_tree}",
            f.file, f.line, f.rust
        ));
    }
    for (labels, _) in &out {
        if let Some(r) = labels
            .iter()
            .find(|l| RESERVED_LABELS.contains(&l.as_str()))
        {
            return Err(format!(
                "{}:{}: the loop label '{r} of {} is reserved; rename it",
                f.file, f.line, f.rust
            ));
        }
    }
    Ok(out)
}

/* Obligations */

/// A resolved spec of an obligation.
#[derive(Debug, Clone)]
pub struct Spec {
    /// The Lean name of the spec.
    pub lean: String,
    /// `true` for a function returning `Bool` (a Rust path), `false` for a `Prop`.
    pub boolean: bool,
}

/// The parameter names of a model in Lean.
pub fn lean_params(f: &ModelFn) -> Vec<String> {
    f.sig.params.iter().map(|p| lean_ident(&p.name)).collect()
}

fn result_parts(f: &ModelFn, res: &str) -> Vec<String> {
    let n = usize::from(f.sig.ret.is_some()) + f.sig.muts().len();
    match n {
        0 => Vec::new(),
        1 => vec![res.to_string()],
        _ => (0..n)
            .map(|i| {
                let mut s = format!("{res}{}", ".2".repeat(i));
                if i + 1 < n {
                    s.push_str(".1");
                }
                s
            })
            .collect(),
    }
}

fn applied(spec: &Spec, args: &[String]) -> String {
    let call = if args.is_empty() {
        spec.lean.clone()
    } else {
        format!("{} {}", spec.lean, args.join(" "))
    };
    if spec.boolean {
        format!("{call} = true")
    } else {
        call
    }
}

/// The statement of an obligation: `∀ args, pre args = true → M args ⦃ r => post args r = true ⦄`
/// for `ensures`, `∀ args, M args = ok (spec args)` for `refines`.
pub fn obligation_statement(
    f: &ModelFn,
    lean: &str,
    label: &str,
    spec: &Spec,
    requires: Option<&Spec>,
) -> String {
    let params = lean_params(f);
    let binders = if params.is_empty() {
        String::new()
    } else {
        format!("∀ {}, ", params.join(" "))
    };
    let pre = requires
        .map(|r| format!("{} → ", applied(r, &params)))
        .unwrap_or_default();
    let call = if params.is_empty() {
        lean.to_string()
    } else {
        format!("{lean} {}", params.join(" "))
    };
    let mut res = "res".to_string();
    while params.contains(&res) {
        res.push('\'');
    }
    let body = if label == "refines" {
        let s = if params.is_empty() {
            spec.lean.clone()
        } else {
            format!("({} {})", spec.lean, params.join(" "))
        };
        format!("{call} = ok {s}")
    } else {
        let mut args = params.clone();
        args.extend(result_parts(f, &res));
        format!("{call} ⦃ {res} => {} ⦄", applied(spec, &args))
    };
    format!("{binders}{pre}{body}")
}

pub const LEAN_HEADER: &str = "-- Generated by cargo lean-rust. Do not edit.\n";

/// The Lean module of the model's functions.
pub fn model_module(crate_ident: &str) -> String {
    format!("LeanRustGen.Model.{crate_ident}.Funs")
}

/// `<prefix>.<crate>.<module path>` (`LeanRustGen.Obligation.probe.inv`).
pub fn module_of(prefix: &str, crate_ident: &str, module: &[String]) -> String {
    let mut s = format!("LeanRustGen.{prefix}.{crate_ident}");
    for m in module {
        s.push('.');
        s.push_str(&lean_ident(m));
    }
    s
}

/// The path of the file of a Lean module relative to the package.
pub fn module_path(module: &str) -> std::path::PathBuf {
    let mut p = std::path::PathBuf::new();
    for c in module.split('.') {
        p.push(c.trim_start_matches('«').trim_end_matches('»'));
    }
    p.set_extension("lean");
    p
}

/// The Rust expression of the `rs:` extern of `f`: `rs:crate::a::f(_,&)`, with `->()` when it
/// returns `()`.
pub fn rust_extern(f: &ModelFn, self_path: Option<&str>, trait_path: Option<&str>) -> String {
    let mut module = String::from("crate");
    for m in &f.module {
        module.push_str("::");
        module.push_str(m);
    }
    let path = match (self_path, trait_path) {
        (Some(t), Some(tr)) => format!("<{t} as {tr}>::{}", f.name),
        (Some(t), None) => format!("{t}::{}", f.name),
        _ => format!("{module}::{}", f.name),
    };
    let modes: Vec<&str> = f
        .sig
        .params
        .iter()
        .map(|p| match p.mode {
            Mode::Value => "_",
            Mode::Ref => "&",
            Mode::RefMut => "&mut",
        })
        .collect();
    let unit = if f.sig.ret.is_none() && !f.sig.muts().is_empty() {
        "->()"
    } else {
        ""
    };
    format!("rs:{path}({}){unit}", modes.join(","))
}
