//! The syntax of `#[lean_rust::model]`, shared by the macro, the build script and
//! `cargo lean-rust`: the attribute keys, the signature of a modelled function, its loops, and
//! the items of a crate with the hashes of their tokens.

use proc_macro2::{TokenStream, TokenTree};
use quote::ToTokens;
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use syn::parse::Parser;
use syn::spanned::Spanned;
use syn::visit::Visit;
use syn::{Attribute, FnArg, ImplItem, Item, LitBool, LitStr, Pat, Path, ReturnType, Type};

/// A spec named by an attribute key.
#[derive(Debug, Clone)]
pub enum SpecRef {
    /// A Rust path to a public function generated from Lean.
    Path(Path),
    /// A Lean name.
    Lean(String),
}

impl SpecRef {
    pub fn describe(&self) -> String {
        match self {
            SpecRef::Path(p) => path_string(p),
            SpecRef::Lean(s) => format!("\"{s}\""),
        }
    }
}

/// The keys of `#[lean_rust::model(..)]`.
#[derive(Debug, Clone, Default)]
pub struct ModelAttr {
    pub refines: Option<SpecRef>,
    pub requires: Option<SpecRef>,
    pub ensures: Vec<(String, SpecRef)>,
    pub check: Option<bool>,
    pub strategy: Option<Path>,
}

impl ModelAttr {
    /// The labels and specs of the obligations: `refines` first, then the `ensures`.
    pub fn obligations(&self) -> Vec<(String, &SpecRef)> {
        let mut out = Vec::new();
        if let Some(r) = &self.refines {
            out.push(("refines".to_string(), r));
        }
        for (l, s) in &self.ensures {
            out.push((l.clone(), s));
        }
        out
    }

    /// The keys of `inner` over the keys of `self`.
    pub fn merge(&self, inner: &ModelAttr) -> ModelAttr {
        ModelAttr {
            refines: inner.refines.clone().or_else(|| self.refines.clone()),
            requires: inner.requires.clone().or_else(|| self.requires.clone()),
            ensures: if inner.ensures.is_empty() {
                self.ensures.clone()
            } else {
                inner.ensures.clone()
            },
            check: inner.check.or(self.check),
            strategy: inner.strategy.clone().or_else(|| self.strategy.clone()),
        }
    }
}

fn spec_value(input: syn::parse::ParseStream) -> syn::Result<SpecRef> {
    if input.peek(LitStr) {
        let s: LitStr = input.parse()?;
        Ok(SpecRef::Lean(s.value()))
    } else {
        Ok(SpecRef::Path(input.parse()?))
    }
}

/// Parses the arguments of `#[lean_rust::model(..)]`.
pub fn parse_model_args(tokens: TokenStream) -> syn::Result<ModelAttr> {
    let mut attr = ModelAttr::default();
    let parser = syn::meta::parser(|meta| {
        if meta.path.is_ident("refines") {
            attr.refines = Some(spec_value(meta.value()?)?);
        } else if meta.path.is_ident("requires") {
            attr.requires = Some(spec_value(meta.value()?)?);
        } else if meta.path.is_ident("ensures") {
            meta.parse_nested_meta(|inner| {
                let Some(label) = inner.path.get_ident() else {
                    return Err(inner.error("expected a label"));
                };
                let label = label.to_string();
                if attr.ensures.iter().any(|(l, _)| *l == label) || label == "refines" {
                    return Err(inner.error(format!("the label `{label}` is used twice")));
                }
                attr.ensures.push((label, spec_value(inner.value()?)?));
                Ok(())
            })?;
        } else if meta.path.is_ident("check") {
            let b: LitBool = meta.value()?.parse()?;
            attr.check = Some(b.value);
        } else if meta.path.is_ident("strategy") {
            attr.strategy = Some(meta.value()?.parse()?);
        } else {
            return Err(
                meta.error("expected `refines`, `requires`, `ensures(..)`, `check` or `strategy`")
            );
        }
        Ok(())
    });
    parser.parse2(tokens)?;
    Ok(attr)
}

/// `true` for `#[model]`, `#[lean_rust::model]` and `#[::lean_rust::model]`.
pub fn is_attr(attr: &Attribute, name: &str) -> bool {
    let segs: Vec<String> = attr
        .path()
        .segments
        .iter()
        .map(|s| s.ident.to_string())
        .collect();
    matches!(segs.as_slice(), [n] if n == name)
        || matches!(segs.as_slice(), [c, n] if c == "lean_rust" && n == name)
}

/// The keys of the `#[lean_rust::model]` attributes of `attrs`, if there is one.
pub fn model_attr(attrs: &[Attribute]) -> syn::Result<Option<ModelAttr>> {
    let mut out: Option<ModelAttr> = None;
    for a in attrs.iter().filter(|a| is_attr(a, "model")) {
        let parsed = match &a.meta {
            syn::Meta::Path(_) => ModelAttr::default(),
            syn::Meta::List(l) => parse_model_args(l.tokens.clone())?,
            syn::Meta::NameValue(nv) => {
                return Err(syn::Error::new(
                    nv.span(),
                    "expected `#[lean_rust::model(..)]`",
                ))
            }
        };
        out = Some(match out {
            Some(o) => o.merge(&parsed),
            None => parsed,
        });
    }
    Ok(out)
}

pub fn path_string(p: &Path) -> String {
    let mut s = String::new();
    if p.leading_colon.is_some() {
        s.push_str("::");
    }
    let segs: Vec<String> = p.segments.iter().map(|s| s.ident.to_string()).collect();
    s.push_str(&segs.join("::"));
    s
}

/* Signatures */

/// How a parameter is passed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Value,
    Ref,
    RefMut,
}

#[derive(Debug, Clone)]
pub struct Param {
    /// The name of the parameter (`self` for the receiver, `arg<i>` for patterns).
    pub name: String,
    pub mode: Mode,
    /// The type, without the reference for `Ref` and `RefMut`; `None` for `self` receivers.
    pub ty: Option<Type>,
    pub is_self: bool,
}

#[derive(Debug, Clone)]
pub struct Sig {
    pub params: Vec<Param>,
    /// `None` for `()`.
    pub ret: Option<Type>,
}

impl Sig {
    /// The parameters passed as `&mut`, whose values after the call are results of the model.
    pub fn muts(&self) -> Vec<&Param> {
        self.params
            .iter()
            .filter(|p| p.mode == Mode::RefMut)
            .collect()
    }
}

fn is_unit(t: &Type) -> bool {
    matches!(t, Type::Tuple(t) if t.elems.is_empty())
}

/// The signature of a function, or an error for the signatures `#[model]` does not support.
pub fn signature(sig: &syn::Signature) -> syn::Result<Sig> {
    if !sig.generics.params.is_empty() {
        return Err(syn::Error::new(
            sig.generics.span(),
            "lean_rust::model: generic functions are not supported",
        ));
    }
    if sig.asyncness.is_some() || sig.unsafety.is_some() || sig.variadic.is_some() {
        return Err(syn::Error::new(
            sig.span(),
            "lean_rust::model: async, unsafe and variadic functions are not supported",
        ));
    }
    let mut params = Vec::new();
    for (i, input) in sig.inputs.iter().enumerate() {
        match input {
            FnArg::Receiver(r) => {
                let mode = match (&r.reference, r.mutability) {
                    (Some(_), Some(_)) => Mode::RefMut,
                    (Some(_), None) => Mode::Ref,
                    (None, _) => Mode::Value,
                };
                if r.colon_token.is_some() && r.reference.is_none() {
                    let ty = &*r.ty;
                    let mode = match ty {
                        Type::Reference(t) if t.mutability.is_some() => Mode::RefMut,
                        Type::Reference(_) => Mode::Ref,
                        _ => Mode::Value,
                    };
                    params.push(Param {
                        name: "self".to_string(),
                        mode,
                        ty: None,
                        is_self: true,
                    });
                    continue;
                }
                params.push(Param {
                    name: "self".to_string(),
                    mode,
                    ty: None,
                    is_self: true,
                });
            }
            FnArg::Typed(pt) => {
                let name = match &*pt.pat {
                    Pat::Ident(pi) if pi.subpat.is_none() => pi.ident.to_string(),
                    _ => format!("arg{i}"),
                };
                let (mode, ty) = match &*pt.ty {
                    Type::Reference(r) if r.mutability.is_some() => {
                        (Mode::RefMut, (*r.elem).clone())
                    }
                    Type::Reference(r) => (Mode::Ref, (*r.elem).clone()),
                    t => (Mode::Value, t.clone()),
                };
                params.push(Param {
                    name,
                    mode,
                    ty: Some(ty),
                    is_self: false,
                });
            }
        }
    }
    let ret = match &sig.output {
        ReturnType::Default => None,
        ReturnType::Type(_, t) if is_unit(t) => None,
        ReturnType::Type(_, t) => Some((**t).clone()),
    };
    Ok(Sig { params, ret })
}

/* Loops */

/// A loop of a function body or a macro call (whose loops are not visible).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LoopNode {
    Loop {
        label: Option<String>,
        line: usize,
        column: usize,
        children: Vec<LoopNode>,
    },
    Macro {
        start: (usize, usize),
        end: (usize, usize),
    },
}

struct LoopVisitor {
    stack: Vec<Vec<LoopNode>>,
}

impl LoopVisitor {
    fn enter(&mut self) {
        self.stack.push(Vec::new());
    }

    fn leave(&mut self, label: Option<&syn::Label>, span: proc_macro2::Span) {
        let children = self.stack.pop().unwrap_or_default();
        let start = span.start();
        self.stack.last_mut().unwrap().push(LoopNode::Loop {
            label: label.map(|l| l.name.ident.to_string()),
            line: start.line,
            column: start.column + 1,
            children,
        });
    }

    fn mac(&mut self, span: proc_macro2::Span) {
        let (s, e) = (span.start(), span.end());
        self.stack.last_mut().unwrap().push(LoopNode::Macro {
            start: (s.line, s.column),
            end: (e.line, e.column),
        });
    }
}

impl<'ast> Visit<'ast> for LoopVisitor {
    fn visit_expr_for_loop(&mut self, e: &'ast syn::ExprForLoop) {
        self.visit_expr(&e.expr);
        self.enter();
        self.visit_block(&e.body);
        self.leave(e.label.as_ref(), e.for_token.span);
    }

    fn visit_expr_while(&mut self, e: &'ast syn::ExprWhile) {
        self.enter();
        self.visit_expr(&e.cond);
        self.visit_block(&e.body);
        self.leave(e.label.as_ref(), e.while_token.span);
    }

    fn visit_expr_loop(&mut self, e: &'ast syn::ExprLoop) {
        self.enter();
        self.visit_block(&e.body);
        self.leave(e.label.as_ref(), e.loop_token.span);
    }

    fn visit_macro(&mut self, m: &'ast syn::Macro) {
        self.mac(m.span());
    }

    fn visit_expr_closure(&mut self, _: &'ast syn::ExprClosure) {}

    fn visit_item(&mut self, _: &'ast Item) {}
}

/// The loops of a function body, as a tree of nesting.
pub fn loops(block: &syn::Block) -> Vec<LoopNode> {
    let mut v = LoopVisitor {
        stack: vec![Vec::new()],
    };
    v.visit_block(block);
    v.stack.pop().unwrap_or_default()
}

/* Hashes */

fn strip_docs(attrs: &mut Vec<Attribute>) {
    attrs.retain(|a| !a.path().is_ident("doc"));
}

struct DocStripper;

impl syn::visit_mut::VisitMut for DocStripper {
    fn visit_attributes_mut(&mut self, attrs: &mut Vec<Attribute>) {
        strip_docs(attrs);
    }
}

fn token_text(ts: TokenStream, out: &mut String) {
    for t in ts {
        match t {
            TokenTree::Group(g) => {
                let (o, c) = match g.delimiter() {
                    proc_macro2::Delimiter::Parenthesis => ("(", ")"),
                    proc_macro2::Delimiter::Brace => ("{", "}"),
                    proc_macro2::Delimiter::Bracket => ("[", "]"),
                    proc_macro2::Delimiter::None => ("", ""),
                };
                out.push_str(o);
                token_text(g.stream(), out);
                out.push_str(c);
                out.push(' ');
            }
            TokenTree::Punct(p) => {
                out.push(p.as_char());
                if p.spacing() == proc_macro2::Spacing::Alone {
                    out.push(' ');
                }
            }
            t => {
                out.push_str(&t.to_string());
                out.push(' ');
            }
        }
    }
}

/// `sha256:<hex>` of the tokens of `item` without its doc comments.
pub fn item_hash<T: ToTokens + Clone>(item: &T, strip: impl FnOnce(&mut T)) -> String {
    let mut item = item.clone();
    strip(&mut item);
    let mut text = String::new();
    token_text(item.to_token_stream(), &mut text);
    let digest = Sha256::digest(text.as_bytes());
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    format!("sha256:{hex}")
}

fn fn_hash(f: &syn::ItemFn) -> String {
    item_hash(f, |f| {
        syn::visit_mut::VisitMut::visit_item_fn_mut(&mut DocStripper, f)
    })
}

fn method_hash(f: &syn::ImplItemFn) -> String {
    item_hash(f, |f| {
        syn::visit_mut::VisitMut::visit_impl_item_fn_mut(&mut DocStripper, f)
    })
}

fn type_hash(i: &Item) -> String {
    item_hash(i, |i| {
        syn::visit_mut::VisitMut::visit_item_mut(&mut DocStripper, i)
    })
}

/* Crate scan */

/// The last identifier of a type path (`crate::inv::Item<T>` → `Item`).
pub fn type_name(t: &Type) -> Option<String> {
    match t {
        Type::Path(p) => p.path.segments.last().map(|s| s.ident.to_string()),
        Type::Reference(r) => type_name(&r.elem),
        Type::Paren(p) => type_name(&p.elem),
        Type::Group(g) => type_name(&g.elem),
        _ => None,
    }
}

/// A modelled function of the crate.
#[derive(Debug, Clone)]
pub struct ModelFn {
    /// `crate::a::f`, `crate::a::Item::f` or `crate::a::<Item as Trait>::f`.
    pub rust: String,
    /// Module path below the crate root, including inline modules.
    pub module: Vec<String>,
    pub self_ty: Option<String>,
    pub trait_name: Option<String>,
    /// The paths of the type and the trait of the impl block, as written.
    pub self_path: Option<Vec<String>>,
    pub trait_path: Option<Vec<String>>,
    pub name: String,
    pub attr: ModelAttr,
    pub sig: Sig,
    pub loops: Vec<LoopNode>,
    /// Path of the file relative to the crate root.
    pub file: String,
    pub line: usize,
}

impl ModelFn {
    /// The name of the rustdoc file: `<module path>::<Self>::<Trait>::<f>.md` with the module
    /// path of `module_path!()`.
    pub fn doc_file(&self, crate_ident: &str) -> String {
        let mut parts = vec![crate_ident.to_string()];
        parts.extend(self.module.iter().cloned());
        parts.extend(self.self_ty.iter().cloned());
        parts.extend(self.trait_name.iter().cloned());
        parts.push(self.name.clone());
        format!("{}.md", parts.join("::"))
    }

    /// The Rust expression calling the function from a sibling module (`super::f`).
    pub fn callee(&self) -> String {
        match (&self.self_ty, &self.trait_name) {
            (Some(t), Some(tr)) => format!("<{t} as {tr}>::{}", self.name),
            (Some(t), None) => format!("{t}::{}", self.name),
            _ => self.name.clone(),
        }
    }
}

/// A `use` of a module: the local name and the path it stands for.
#[derive(Debug, Clone, Default)]
pub struct Uses {
    pub names: BTreeMap<String, Vec<String>>,
    pub globs: Vec<Vec<String>>,
}

/// What a scan of `src/**/*.rs` finds.
#[derive(Debug, Default)]
pub struct CrateItems {
    pub models: Vec<ModelFn>,
    /// `#[lean_rust::opaque]` functions, as unit names.
    pub opaque: Vec<String>,
    /// Hash of every function, method and type, by unit name.
    pub hashes: BTreeMap<String, String>,
    /// `use` declarations, by module path.
    pub uses: BTreeMap<Vec<String>, Uses>,
    /// `#[lean_rust::exported("<Lean name>")]` functions, by unit name: the Lean name and the
    /// file.
    pub exported: BTreeMap<String, (String, String)>,
    /// Inline and file modules, by module path.
    pub modules: Vec<Vec<String>>,
    pub errors: Vec<String>,
}

fn unit_name(module: &[String], rest: &[&str]) -> String {
    let mut s = String::from("crate");
    for m in module {
        s.push_str("::");
        s.push_str(m);
    }
    for r in rest {
        s.push_str("::");
        s.push_str(r);
    }
    s
}

/// The unit name of a trait method: `crate::a::<Item as Trait>::f`.
pub fn trait_unit(module: &[String], self_ty: &str, trait_name: &str, f: &str) -> String {
    let mut s = unit_name(module, &[]);
    s.push_str(&format!("::<{self_ty} as {trait_name}>::{f}"));
    s
}

fn exported_name(attrs: &[Attribute]) -> Option<String> {
    for a in attrs.iter().filter(|a| is_attr(a, "exported")) {
        if let Ok(s) = a.parse_args::<LitStr>() {
            return Some(s.value());
        }
    }
    None
}

fn collect_use(tree: &syn::UseTree, prefix: &mut Vec<String>, uses: &mut Uses) {
    match tree {
        syn::UseTree::Path(p) => {
            prefix.push(p.ident.to_string());
            collect_use(&p.tree, prefix, uses);
            prefix.pop();
        }
        syn::UseTree::Name(n) => {
            let name = n.ident.to_string();
            if name == "self" {
                if let Some(last) = prefix.last() {
                    uses.names.insert(last.clone(), prefix.clone());
                }
            } else {
                let mut p = prefix.clone();
                p.push(name.clone());
                uses.names.insert(name, p);
            }
        }
        syn::UseTree::Rename(r) => {
            let mut p = prefix.clone();
            if r.ident != "self" {
                p.push(r.ident.to_string());
            }
            uses.names.insert(r.rename.to_string(), p);
        }
        syn::UseTree::Glob(_) => uses.globs.push(prefix.clone()),
        syn::UseTree::Group(g) => {
            for t in &g.items {
                collect_use(t, prefix, uses);
            }
        }
    }
}

struct Scanner<'a> {
    file: String,
    module: Vec<String>,
    out: &'a mut CrateItems,
}

impl Scanner<'_> {
    fn error(&mut self, span: proc_macro2::Span, msg: impl std::fmt::Display) {
        let at = span.start();
        self.out.errors.push(format!(
            "{}:{}:{}: {msg}",
            self.file,
            at.line,
            at.column + 1
        ));
    }

    fn model_fn(
        &mut self,
        attr: ModelAttr,
        sig: &syn::Signature,
        block: &syn::Block,
        self_ty: Option<String>,
        trait_name: Option<String>,
        paths: (Option<Vec<String>>, Option<Vec<String>>),
    ) {
        let name = sig.ident.to_string();
        let rust = match (&self_ty, &trait_name) {
            (Some(t), Some(tr)) => trait_unit(&self.module, t, tr, &name),
            (Some(t), None) => unit_name(&self.module, &[t, &name]),
            _ => unit_name(&self.module, &[&name]),
        };
        let parsed = match signature(sig) {
            Ok(s) => s,
            Err(e) => {
                self.error(e.span(), e);
                return;
            }
        };
        self.out.models.push(ModelFn {
            rust,
            module: self.module.clone(),
            self_ty,
            trait_name,
            self_path: paths.0,
            trait_path: paths.1,
            name,
            attr,
            sig: parsed,
            loops: loops(block),
            file: self.file.clone(),
            line: sig.ident.span().start().line,
        });
    }

    fn item_impl(&mut self, i: &syn::ItemImpl) {
        let Some(self_ty) = type_name(&i.self_ty) else {
            return;
        };
        let trait_name = i
            .trait_
            .as_ref()
            .and_then(|(_, p, _)| p.segments.last().map(|s| s.ident.to_string()));
        let segs = |p: &Path| {
            p.segments
                .iter()
                .map(|s| s.ident.to_string())
                .collect::<Vec<_>>()
        };
        let self_path = match &*i.self_ty {
            Type::Path(p) => Some(segs(&p.path)),
            _ => None,
        };
        let trait_path = i.trait_.as_ref().map(|(_, p, _)| segs(p));
        let outer = match model_attr(&i.attrs) {
            Ok(a) => a,
            Err(e) => {
                self.error(e.span(), e);
                return;
            }
        };
        for item in &i.items {
            let ImplItem::Fn(f) = item else { continue };
            let name = f.sig.ident.to_string();
            let unit = match &trait_name {
                Some(tr) => trait_unit(&self.module, &self_ty, tr, &name),
                None => unit_name(&self.module, &[&self_ty, &name]),
            };
            self.out.hashes.insert(unit.clone(), method_hash(f));
            if f.attrs.iter().any(|a| is_attr(a, "opaque")) {
                self.out.opaque.push(unit.clone());
            }
            if let Some(n) = exported_name(&f.attrs) {
                self.out.exported.insert(unit, (n, self.file.clone()));
            }
            let inner = match model_attr(&f.attrs) {
                Ok(a) => a,
                Err(e) => {
                    self.error(e.span(), e);
                    continue;
                }
            };
            let attr = match (&outer, inner) {
                (Some(o), Some(i)) => o.merge(&i),
                (Some(o), None) => o.clone(),
                (None, Some(i)) => i,
                (None, None) => continue,
            };
            self.model_fn(
                attr,
                &f.sig,
                &f.block,
                Some(self_ty.clone()),
                trait_name.clone(),
                (self_path.clone(), trait_path.clone()),
            );
        }
    }
}

impl<'ast> Visit<'ast> for Scanner<'_> {
    fn visit_item(&mut self, item: &'ast Item) {
        match item {
            Item::Fn(f) => {
                let name = f.sig.ident.to_string();
                let unit = unit_name(&self.module, &[&name]);
                self.out.hashes.insert(unit.clone(), fn_hash(f));
                if f.attrs.iter().any(|a| is_attr(a, "opaque")) {
                    self.out.opaque.push(unit.clone());
                }
                if let Some(n) = exported_name(&f.attrs) {
                    self.out.exported.insert(unit, (n, self.file.clone()));
                }
                match model_attr(&f.attrs) {
                    Ok(Some(attr)) => {
                        self.model_fn(attr, &f.sig, &f.block, None, None, (None, None))
                    }
                    Ok(None) => {}
                    Err(e) => self.error(e.span(), e),
                }
            }
            Item::Struct(s) => {
                let unit = unit_name(&self.module, &[&s.ident.to_string()]);
                self.out.hashes.insert(unit, type_hash(item));
            }
            Item::Enum(e) => {
                let unit = unit_name(&self.module, &[&e.ident.to_string()]);
                self.out.hashes.insert(unit, type_hash(item));
            }
            Item::Impl(i) => self.item_impl(i),
            Item::Use(u) => {
                let uses = self.out.uses.entry(self.module.clone()).or_default();
                collect_use(&u.tree, &mut Vec::new(), uses);
            }
            Item::Mod(m) => {
                self.module.push(m.ident.to_string());
                self.out.modules.push(self.module.clone());
                if let Some((_, items)) = &m.content {
                    for i in items {
                        self.visit_item(i);
                    }
                }
                self.module.pop();
            }
            _ => {}
        }
    }
}

/// Scans the parsed file `ast` (at `file`, relative to the crate root, in module `module`).
pub fn scan_file(file: &str, module: Vec<String>, ast: &syn::File, out: &mut CrateItems) {
    if !out.modules.contains(&module) {
        out.modules.push(module.clone());
    }
    let mut s = Scanner {
        file: file.to_string(),
        module,
        out,
    };
    for item in &ast.items {
        s.visit_item(item);
    }
}

/// Module path of a file relative to the crate root: `src/a/b.rs` and `src/a/b/mod.rs` →
/// `[a, b]`; `src/lib.rs`, `src/main.rs` and `src/bin/*.rs` are crate roots.
pub fn file_module(rel: &str) -> Vec<String> {
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

impl CrateItems {
    /// The absolute path (segments after `crate`) that `path` names in `module`, following
    /// the `use` declarations of the modules.
    pub fn resolve(&self, module: &[String], path: &Path) -> Vec<String> {
        let segs: Vec<String> = path.segments.iter().map(|s| s.ident.to_string()).collect();
        self.resolve_segments(module, &segs, 0)
    }

    pub fn resolve_segments(
        &self,
        module: &[String],
        segs: &[String],
        depth: usize,
    ) -> Vec<String> {
        let Some(first) = segs.first() else {
            return module.to_vec();
        };
        match first.as_str() {
            "crate" => return segs[1..].to_vec(),
            "self" => {
                let mut out = module.to_vec();
                out.extend(segs[1..].iter().cloned());
                return out;
            }
            "super" => {
                let mut out = module.to_vec();
                let mut rest = segs;
                while rest.first().is_some_and(|s| s == "super") {
                    out.pop();
                    rest = &rest[1..];
                }
                out.extend(rest.iter().cloned());
                return out;
            }
            _ => {}
        }
        if depth < 16 {
            if let Some(u) = self.uses.get(module) {
                if let Some(target) = u.names.get(first) {
                    let mut full = target.clone();
                    full.extend(segs[1..].iter().cloned());
                    let parent = module.to_vec();
                    return self.resolve_segments(&parent, &full, depth + 1);
                }
            }
        }
        let mut local = module.to_vec();
        local.push(first.clone());
        let known_local = self.modules.contains(&local)
            || self
                .hashes
                .keys()
                .any(|k| k.starts_with(&unit_name(&local, &[])));
        if !known_local && depth < 16 {
            if let Some(u) = self.uses.get(module) {
                for g in &u.globs {
                    let mut full = g.clone();
                    full.extend(segs.iter().cloned());
                    let resolved = self.resolve_segments(module, &full, depth + 1);
                    let mut parent = resolved.clone();
                    parent.pop();
                    if self.modules.contains(&parent) {
                        return resolved;
                    }
                }
            }
        }
        let mut out = module.to_vec();
        out.extend(segs.iter().cloned());
        out
    }
}
