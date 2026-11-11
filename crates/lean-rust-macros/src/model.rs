//! `#[lean_rust::model]` and `#[derive(lean_rust::Model)]`.

use lean_rust_build::model::{
    instance_name, model_attr, parse_model_args, signature, Mode, ModelAttr, Sig, SpecRef,
    TypeParam,
};
use proc_macro2::{Span, TokenStream};
use quote::{format_ident, quote};
use syn::{Ident, ImplItem, Item, Path, Type};

/// Where the function is: a free function, or a method of `self_ty` (implementing `trait_`).
struct Owner {
    self_ty: Option<Type>,
    trait_: Option<Path>,
    /// The generics of the impl block.
    generics: Option<syn::Generics>,
}

/// The rustdoc attribute of a model, and an item reporting a missing build script.
fn doc_attr(rest: &str) -> (syn::Attribute, TokenStream) {
    let file = format!("::{rest}.md");
    let doc_dir =
        std::env::var_os("OUT_DIR").map(|d| std::path::Path::new(&d).join("lean_rust").join("doc"));
    if doc_dir.is_some_and(|d| d.is_dir()) {
        (
            syn::parse_quote! {
                #[doc = include_str!(concat!(env!("OUT_DIR"), "/lean_rust/doc/", module_path!(), #file))]
            },
            TokenStream::new(),
        )
    } else {
        let msg = "lean_rust::model: the build script did not write the documentation of the \
                   models. Add `build.rs` with `fn main() { lean_rust_build::Builder::new().compile().unwrap(); }` \
                   and `lean-rust-build` to [build-dependencies]";
        (
            syn::parse_quote! { #[doc = ""] },
            quote! { const _: () = ::core::compile_error!(#msg); },
        )
    }
}

/// `self::x` and `super::x` one module deeper (`depth` times).
fn deeper(p: &Path, depth: usize) -> TokenStream {
    let first = p.segments.first().map(|s| s.ident.to_string());
    let supers = (0..depth).map(|_| quote! { super:: });
    match first.as_deref() {
        Some("self") => {
            let rest = p.segments.iter().skip(1);
            let supers = (0..depth).map(|_| quote! { super }).collect::<Vec<_>>();
            quote! { #(#supers)::* :: #(#rest)::* }
        }
        Some("super") if p.leading_colon.is_none() => quote! { #(#supers)* #p },
        _ => quote! { #p },
    }
}

/// The path of the copy of a generated spec: `a::b::f` → `a::b::__lean_rust_spec::f`.
fn copy_path(p: &Path, depth: usize) -> TokenStream {
    let mut p = p.clone();
    let last = p.segments.pop();
    p.segments.push(syn::PathSegment::from(Ident::new(
        "__lean_rust_spec",
        Span::call_site(),
    )));
    if let Some(l) = last {
        p.segments.push(l);
    }
    deeper(&p, depth)
}

fn owned_type(t: &Type) -> TokenStream {
    match t {
        Type::Slice(s) => {
            let e = &s.elem;
            quote! { ::std::vec::Vec<#e> }
        }
        Type::Path(p) if p.path.is_ident("str") => quote! { ::std::string::String },
        t => quote! { #t },
    }
}

struct Adapter {
    params: Vec<TokenStream>,
    /// The owned types of the parameters, for the strategy of the test.
    owned: Vec<TokenStream>,
    /// How the test passes each owned argument to the adapter.
    pass: Vec<TokenStream>,
    names: Vec<Ident>,
    specs: Vec<TokenStream>,
    call: TokenStream,
    results: Vec<TokenStream>,
}

fn adapter(sig: &Sig, callee: TokenStream, owner: &Owner) -> Adapter {
    let mut a = Adapter {
        params: Vec::new(),
        owned: Vec::new(),
        pass: Vec::new(),
        names: Vec::new(),
        specs: Vec::new(),
        call: TokenStream::new(),
        results: Vec::new(),
    };
    let mut args = Vec::new();
    for p in &sig.params {
        let name = if p.is_self {
            format_ident!("self_")
        } else {
            format_ident!("{}", p.name)
        };
        let ty = match (&p.ty, &owner.self_ty) {
            (Some(t), _) => quote! { #t },
            (None, Some(t)) => quote! { #t },
            (None, None) => quote! { Self },
        };
        let owned = match &p.ty {
            Some(t) if p.mode == Mode::Ref => owned_type(t),
            _ => ty.clone(),
        };
        match p.mode {
            Mode::Value => {
                a.params.push(quote! { #name: #ty });
                args.push(quote! { #name });
                a.pass.push(quote! { #name.clone() });
            }
            Mode::Ref => {
                a.params.push(quote! { #name: &#ty });
                args.push(quote! { #name });
                a.pass.push(quote! { &#name });
            }
            Mode::RefMut => {
                a.params.push(quote! { mut #name: #ty });
                args.push(quote! { &mut #name });
                a.pass.push(quote! { #name.clone() });
                a.results
                    .push(quote! { ::lean_rust::spec::SpecArg::spec_arg(&#name) });
            }
        }
        a.owned.push(owned);
        let s = format_ident!("__s_{}", name);
        a.specs
            .push(quote! { let #s = ::lean_rust::spec::SpecArg::spec_arg(&#name); });
        a.names.push(name);
    }
    a.call = quote! { #callee(#(#args),*) };
    if sig.ret.is_some() {
        a.results
            .insert(0, quote! { ::lean_rust::spec::SpecArg::spec_arg(&__r) });
    }
    a
}

fn nested_tuple(xs: &[TokenStream]) -> TokenStream {
    match xs {
        [] => quote! { () },
        [x] => x.clone(),
        [x, rest @ ..] => {
            let r = nested_tuple(rest);
            quote! { (#x, #r) }
        }
    }
}

fn spec_names(a: &Adapter) -> Vec<Ident> {
    a.names.iter().map(|n| format_ident!("__s_{}", n)).collect()
}

/// The adapter functions of `attr`, calling the specs at `spec_path` (their path, or the path
/// of their copy). With `report`, `refines` and `ensures_<label>` return `Err` with the values
/// of the function and the spec when they disagree, for the message of the test.
fn adapter_fns(
    attr: &ModelAttr,
    a: &Adapter,
    has_ret: bool,
    spec_path: &dyn Fn(&Path) -> TokenStream,
    suffix: &str,
    report: bool,
) -> TokenStream {
    let requires = format_ident!("requires{}", suffix);
    let refines = format_ident!("refines{}", suffix);
    let params = &a.params;
    let specs = &a.specs;
    let s = spec_names(a);
    let call = &a.call;
    let call_stmt = if has_ret {
        quote! { let __r = #call; }
    } else {
        quote! { #call; }
    };
    let mut out = TokenStream::new();
    if let Some(SpecRef::Path(p)) = &attr.requires {
        let p = spec_path(p);
        out.extend(quote! {
            pub fn #requires(#(#params),*) -> bool {
                #(#specs)*
                #p(#(#s),*)
            }
        });
    }
    if let Some(SpecRef::Path(p)) = &attr.refines {
        let spec = lean_rust_build::model::path_string(p);
        let p = spec_path(p);
        let value = nested_tuple(&a.results);
        out.extend(if report {
            quote! {
                pub fn #refines(#(#params),*) -> ::core::result::Result<(), ::std::string::String> {
                    use ::lean_rust::check::{ShowDebug as _, ShowOther as _};
                    #(#specs)*
                    #call_stmt
                    let __value = #value;
                    let __spec = #p(#(#s),*);
                    if __spec == __value {
                        ::core::result::Result::Ok(())
                    } else {
                        ::core::result::Result::Err(::std::format!(
                            "the function returned {}, and the spec {} returned {}",
                            (&::lean_rust::check::Shown(&__value)).show(),
                            #spec,
                            (&::lean_rust::check::Shown(&__spec)).show(),
                        ))
                    }
                }
            }
        } else {
            quote! {
                pub fn #refines(#(#params),*) -> bool {
                    #(#specs)*
                    #call_stmt
                    #p(#(#s),*) == #value
                }
            }
        });
    }
    for (label, spec) in &attr.ensures {
        let SpecRef::Path(p) = spec else { continue };
        let spec = lean_rust_build::model::path_string(p);
        let p = spec_path(p);
        let f = format_ident!("ensures_{}{}", label, suffix);
        let results = &a.results;
        let shown = nested_tuple(results);
        out.extend(if report {
            quote! {
                pub fn #f(#(#params),*) -> ::core::result::Result<(), ::std::string::String> {
                    use ::lean_rust::check::{ShowDebug as _, ShowOther as _};
                    #(#specs)*
                    #call_stmt
                    let __shown = (&::lean_rust::check::Shown(&#shown)).show();
                    if #p(#(#s,)* #(#results),*) {
                        ::core::result::Result::Ok(())
                    } else {
                        ::core::result::Result::Err(::std::format!(
                            "the spec {} returned false for the result {}",
                            #spec,
                            __shown,
                        ))
                    }
                }
            }
        } else {
            quote! {
                pub fn #f(#(#params),*) -> bool {
                    #(#specs)*
                    #call_stmt
                    #p(#(#s,)* #(#results),*)
                }
            }
        });
    }
    out
}

/// The proptests of the adapter functions with `suffix`; a strategy function is called with
/// `turbofish` (the types of the instance of a generic function).
fn tests(attr: &ModelAttr, a: &Adapter, suffix: &str, turbofish: TokenStream) -> TokenStream {
    if attr.check == Some(false) {
        return TokenStream::new();
    }
    let mut checks = Vec::new();
    if matches!(attr.refines, Some(SpecRef::Path(_))) {
        checks.push((
            format_ident!("check_refines{}", suffix),
            format_ident!("refines{}", suffix),
        ));
    }
    for (label, spec) in &attr.ensures {
        if matches!(spec, SpecRef::Path(_)) {
            checks.push((
                format_ident!("check_ensures_{}{}", label, suffix),
                format_ident!("ensures_{}{}", label, suffix),
            ));
        }
    }
    if checks.is_empty() {
        return TokenStream::new();
    }
    let owned = &a.owned;
    let strategy = match &attr.strategy {
        Some(p) => {
            let p = deeper(p, 1);
            quote! { #p #turbofish () }
        }
        None if owned.len() == 1 => {
            let t = &owned[0];
            quote! { ::lean_rust::check::proptest::prelude::any::<#t>() }
        }
        None => quote! { (#(::lean_rust::check::proptest::prelude::any::<#owned>()),*) },
    };
    let requires = format_ident!("requires{}", suffix);
    let names = &a.names;
    let pat = if names.len() == 1 {
        quote! { #(#names)* }
    } else {
        quote! { (#(#names),*) }
    };
    let pass = &a.pass;
    let assume = if matches!(attr.requires, Some(SpecRef::Path(_))) {
        quote! {
            {
                let #pat = __args.clone();
                ::lean_rust::check::proptest::prop_assume!(copy::#requires(#(#pass),*));
            }
        }
    } else {
        TokenStream::new()
    };
    let fns = checks.iter().map(|(test, f)| {
        quote! {
            #[test]
            fn #test(__args in #strategy) {
                #assume
                let #pat = __args;
                let __checked = copy::#f(#(#pass),*);
                ::lean_rust::check::proptest::prop_assert!(
                    __checked.is_ok(),
                    "{}",
                    __checked.err().unwrap_or_default()
                );
            }
        }
    });
    quote! {
        #[cfg(test)]
        ::lean_rust::check::proptest::proptest! {
            #(#fns)*
        }
    }
}

/// Replaces the type parameters by the types of an instance.
struct Subst<'a>(&'a [(String, Type)]);

impl syn::visit_mut::VisitMut for Subst<'_> {
    fn visit_type_mut(&mut self, t: &mut Type) {
        if let Type::Path(p) = t {
            if p.qself.is_none() {
                if let Some(id) = p.path.get_ident() {
                    if let Some((_, to)) = self.0.iter().find(|(n, _)| id == n) {
                        *t = to.clone();
                        return;
                    }
                }
            }
        }
        syn::visit_mut::visit_type_mut(self, t);
    }
}

fn subst_type(t: &Type, map: &[(String, Type)]) -> Type {
    let mut t = t.clone();
    syn::visit_mut::VisitMut::visit_type_mut(&mut Subst(map), &mut t);
    t
}

/// The types of the type parameters `generics` in `instance`: the type itself for one
/// parameter, the elements of a tuple for several.
fn instance_types(generics: &[TypeParam], instance: &Type) -> syn::Result<Vec<(String, Type)>> {
    let types: Vec<Type> = match instance {
        Type::Tuple(t) if generics.len() != 1 => t.elems.iter().cloned().collect(),
        t => vec![t.clone()],
    };
    if types.len() != generics.len() {
        return Err(syn::Error::new_spanned(
            instance,
            format!(
                "lean_rust::model: the function has {} type parameters; give a tuple of {} types",
                generics.len(),
                generics.len()
            ),
        ));
    }
    Ok(generics.iter().map(|g| g.name.clone()).zip(types).collect())
}

/// The adapter module of one function: for a generic function, the adapters and tests of
/// each type of `instances`, with the suffix `_<type>`.
fn expand_fn(
    attr: &ModelAttr,
    sig: &syn::Signature,
    owner: &Owner,
    doc_rest: &str,
) -> syn::Result<TokenStream> {
    let parsed = signature(sig, owner.generics.as_ref())?;
    let name = &sig.ident;
    let fn_generics: Vec<String> = signature(sig, None)?
        .generics
        .into_iter()
        .map(|g| g.name)
        .collect();
    let mut cases: Vec<(String, Vec<(String, Type)>)> = Vec::new();
    if parsed.generics.is_empty() {
        cases.push((String::new(), Vec::new()));
    } else {
        if attr.instances.is_empty() {
            return Err(syn::Error::new_spanned(
                &sig.ident,
                "lean_rust::model: a generic function needs `instances = [..]`: the types its tests run with",
            ));
        }
        for inst in &attr.instances {
            cases.push((
                format!("_{}", instance_name(inst)),
                instance_types(&parsed.generics, inst)?,
            ));
        }
    }
    let mut real = TokenStream::new();
    let mut copies = TokenStream::new();
    let mut tests_out = TokenStream::new();
    for (suffix, map) in &cases {
        let mut sig_i = parsed.clone();
        for p in &mut sig_i.params {
            p.ty = p.ty.as_ref().map(|t| subst_type(t, map));
        }
        sig_i.ret = sig_i.ret.as_ref().map(|t| subst_type(t, map));
        let owner_i = Owner {
            self_ty: owner.self_ty.as_ref().map(|t| subst_type(t, map)),
            trait_: owner.trait_.clone(),
            generics: None,
        };
        let own: Vec<&Type> = fn_generics
            .iter()
            .filter_map(|g| map.iter().find(|(n, _)| n == g).map(|(_, t)| t))
            .collect();
        let turbofish = if own.is_empty() {
            TokenStream::new()
        } else {
            quote! { ::<#(#own),*> }
        };
        let all: Vec<&Type> = map.iter().map(|(_, t)| t).collect();
        let strategy_turbofish = if all.is_empty() {
            TokenStream::new()
        } else {
            quote! { ::<#(#all),*> }
        };
        let callee = |depth: usize| {
            let supers = (0..depth).map(|_| quote! { super:: });
            match (&owner_i.self_ty, &owner_i.trait_) {
                (Some(t), Some(tr)) => quote! { <#t as #tr>::#name #turbofish },
                (Some(t), None) => quote! { <#t>::#name #turbofish },
                _ => quote! { #(#supers)* #name #turbofish },
            }
        };
        let a = adapter(&sig_i, callee(1), &owner_i);
        let a2 = adapter(&sig_i, callee(2), &owner_i);
        let has_ret = sig_i.ret.is_some();
        real.extend(adapter_fns(
            attr,
            &a,
            has_ret,
            &|p| deeper(p, 1),
            suffix,
            false,
        ));
        copies.extend(adapter_fns(
            attr,
            &a2,
            has_ret,
            &|p| copy_path(p, 2),
            suffix,
            true,
        ));
        tests_out.extend(tests(attr, &a, suffix, strategy_turbofish));
    }
    let module = format_ident!("__lean_rust_{}", doc_rest.replace("::", "_"));
    Ok(quote! {
        #[doc(hidden)]
        #[allow(dead_code, non_snake_case, unused_mut, unused_imports, unused_variables, clippy::all)]
        mod #module {
            use super::*;
            #real
            #[cfg(test)]
            mod copy {
                use super::super::*;
                #copies
            }
            #tests_out
        }
    })
}

fn type_ident(t: &Type) -> Option<String> {
    lean_rust_build::model::type_name(t)
}

pub fn extracting() -> bool {
    std::env::var("LEAN_RUST_EXTRACTING").as_deref() == Ok("1")
}

/// The item alone, for the compilation by Charon (`cargo lean-rust extract`): the specs may
/// not be generated yet.
fn bare(item: Item) -> TokenStream {
    match item {
        Item::Fn(mut f) => {
            f.attrs.push(syn::parse_quote!(#[allow(unused_labels)]));
            quote! { #f }
        }
        Item::Impl(mut imp) => {
            for it in &mut imp.items {
                if let ImplItem::Fn(m) = it {
                    m.attrs
                        .retain(|a| !lean_rust_build::model::is_attr(a, "model"));
                    m.attrs.push(syn::parse_quote!(#[allow(unused_labels)]));
                }
            }
            quote! { #imp }
        }
        other => quote! { #other },
    }
}

pub fn expand(attr: TokenStream, item: TokenStream) -> syn::Result<TokenStream> {
    let outer = parse_model_args(attr)?;
    let item: Item = syn::parse2(item)?;
    if extracting() {
        return Ok(bare(item));
    }
    match item {
        Item::Fn(mut f) => {
            let rest = f.sig.ident.to_string();
            let module = expand_fn(
                &outer,
                &f.sig,
                &Owner {
                    self_ty: None,
                    trait_: None,
                    generics: None,
                },
                &rest,
            )?;
            if f.sig
                .inputs
                .iter()
                .any(|i| matches!(i, syn::FnArg::Receiver(_)))
            {
                return Err(syn::Error::new_spanned(
                    &f.sig,
                    "lean_rust::model: put #[lean_rust::model] on the impl block of a method",
                ));
            }
            let (doc, missing) = doc_attr(&rest);
            f.attrs.push(doc);
            f.attrs.push(syn::parse_quote!(#[allow(unused_labels)]));
            Ok(quote! { #f #module #missing })
        }
        Item::Impl(mut imp) => {
            if outer.refines.is_some() || outer.requires.is_some() || !outer.ensures.is_empty() {
                return Err(syn::Error::new_spanned(
                    &imp.self_ty,
                    "lean_rust::model: on an impl block, give the specs on the methods",
                ));
            }
            let Some(ty_name) = type_ident(&imp.self_ty) else {
                return Err(syn::Error::new_spanned(
                    &imp.self_ty,
                    "lean_rust::model: the type of the impl block must be a path",
                ));
            };
            let trait_ = imp.trait_.as_ref().map(|(p, _)| p.clone());
            let trait_name = trait_
                .as_ref()
                .and_then(|p| p.segments.last().map(|s| s.ident.to_string()));
            let owner = Owner {
                self_ty: Some((*imp.self_ty).clone()),
                trait_,
                generics: Some(imp.generics.clone()),
            };
            let mut modules = TokenStream::new();
            for it in &mut imp.items {
                let ImplItem::Fn(m) = it else { continue };
                let inner = model_attr(&m.attrs)?;
                m.attrs
                    .retain(|a| !lean_rust_build::model::is_attr(a, "model"));
                let attr = match inner {
                    Some(i) => outer.merge(&i),
                    None => outer.clone(),
                };
                let mut rest = vec![ty_name.clone()];
                rest.extend(trait_name.iter().cloned());
                rest.push(m.sig.ident.to_string());
                let rest = rest.join("::");
                modules.extend(expand_fn(&attr, &m.sig, &owner, &rest)?);
                let (doc, missing) = doc_attr(&rest);
                m.attrs.push(doc);
                m.attrs.push(syn::parse_quote!(#[allow(unused_labels)]));
                modules.extend(missing);
            }
            Ok(quote! { #imp #modules })
        }
        other => Err(syn::Error::new_spanned(
            other,
            "lean_rust::model applies to functions and impl blocks",
        )),
    }
}

/* derive(Model) */

/// `true` when `t` mentions one of the type parameters `params`.
fn mentions(t: &Type, params: &[String]) -> bool {
    struct V<'a>(&'a [String], bool);
    impl<'ast> syn::visit::Visit<'ast> for V<'_> {
        fn visit_path(&mut self, p: &'ast syn::Path) {
            if let Some(id) = p.get_ident() {
                if self.0.iter().any(|n| id == n) {
                    self.1 = true;
                }
            }
            syn::visit::visit_path(self, p);
        }
    }
    let mut v = V(params, false);
    syn::visit::Visit::visit_type(&mut v, t);
    v.1
}

/// The scalar size of a field of type `t`: a field of a type parameter is an object, as in
/// Lean's layout of a polymorphic structure.
fn scalar_size(t: &Type, params: &[String]) -> TokenStream {
    if mentions(t, params) {
        quote! { 0u32 }
    } else {
        quote! { <#t as ::lean_rust::runtime::Model>::SCALAR_SIZE }
    }
}

fn field_layout(tys: &[&Type], params: &[String]) -> TokenStream {
    let sizes = tys.iter().map(|t| scalar_size(t, params));
    quote! {
        ::lean_rust::runtime::ctor_layout(&[#(#sizes),*])
    }
}

/// `to_model` of a constructor with tag `tag` and the field values `vals` of types `tys`.
fn build_ctor(tag: usize, vals: &[TokenStream], tys: &[&Type], params: &[String]) -> TokenStream {
    let tag = tag as u32;
    if vals.is_empty() {
        return quote! { ::lean_rust::runtime::lean_box(#tag as usize) };
    }
    let layout = field_layout(tys, params);
    let sets = vals.iter().zip(tys).enumerate().map(|(i, (v, t))| {
        let size = scalar_size(t, params);
        quote! {
            if #size == 0 {
                ::lean_rust::runtime::lean_ctor_set(__o, __slot[#i], ::lean_rust::runtime::Model::to_model(#v));
            } else {
                ::lean_rust::runtime::Model::set_scalar(#v, __o, ::lean_rust::runtime::scalar_offset(__objs, __slot[#i]));
            }
        }
    });
    quote! {{
        let (__slot, __objs, __ssz) = #layout;
        let __o = ::lean_rust::runtime::lean_alloc_ctor(#tag, __objs, __ssz);
        #(#sets)*
        __o
    }}
}

fn read_fields(tys: &[&Type], params: &[String]) -> (TokenStream, Vec<TokenStream>) {
    let layout = field_layout(tys, params);
    let reads = tys
        .iter()
        .enumerate()
        .map(|(i, t)| {
            let size = scalar_size(t, params);
            quote! {
                if #size == 0 {
                    <#t as ::lean_rust::runtime::Model>::from_model(::lean_rust::runtime::lean_ctor_get(o, __slot[#i]))
                } else {
                    <#t as ::lean_rust::runtime::Model>::get_scalar(o, ::lean_rust::runtime::scalar_offset(__objs, __slot[#i]))
                }
            }
        })
        .collect();
    (quote! { let (__slot, __objs, _) = #layout; }, reads)
}

fn construct(path: TokenStream, fields: &syn::Fields, vals: Vec<TokenStream>) -> TokenStream {
    match fields {
        syn::Fields::Named(n) => {
            let names = n.named.iter().map(|f| f.ident.clone().unwrap());
            quote! { #path { #(#names: #vals),* } }
        }
        syn::Fields::Unnamed(_) => quote! { #path(#(#vals),*) },
        syn::Fields::Unit => path,
    }
}

fn bindings(fields: &syn::Fields) -> (TokenStream, Vec<TokenStream>) {
    let vars: Vec<Ident> = (0..fields.len())
        .map(|i| format_ident!("__f{}", i))
        .collect();
    let pat = match fields {
        syn::Fields::Named(n) => {
            let names = n.named.iter().map(|f| f.ident.clone().unwrap());
            quote! { { #(#names: #vars),* } }
        }
        syn::Fields::Unnamed(_) => quote! { (#(#vars),*) },
        syn::Fields::Unit => TokenStream::new(),
    };
    (pat, vars.iter().map(|v| quote! { #v }).collect())
}

pub fn derive(input: TokenStream) -> syn::Result<TokenStream> {
    let input: syn::DeriveInput = syn::parse2(input)?;
    if let Some(c) = input.generics.const_params().next() {
        return Err(syn::Error::new_spanned(
            c,
            "derive(lean_rust::Model): const generics are not supported",
        ));
    }
    let params: Vec<String> = input
        .generics
        .type_params()
        .map(|p| p.ident.to_string())
        .collect();
    let name = &input.ident;
    let body = match &input.data {
        syn::Data::Struct(s) => {
            let tys: Vec<&Type> = s.fields.iter().map(|f| &f.ty).collect();
            let (pat, vars) = bindings(&s.fields);
            if tys.len() == 1 {
                let t = tys[0];
                let read = construct(
                    quote! { #name },
                    &s.fields,
                    vec![quote! { <#t as ::lean_rust::runtime::Model>::from_model(o) }],
                );
                let read_scalar = construct(
                    quote! { #name },
                    &s.fields,
                    vec![quote! { <#t as ::lean_rust::runtime::Model>::get_scalar(o, off) }],
                );
                let v = &vars[0];
                quote! {
                    const SCALAR_SIZE: u32 = <#t as ::lean_rust::runtime::Model>::SCALAR_SIZE;
                    unsafe fn to_model(self) -> ::lean_rust::runtime::Obj {
                        let #name #pat = self;
                        ::lean_rust::runtime::Model::to_model(#v)
                    }
                    unsafe fn from_model(o: ::lean_rust::runtime::Obj) -> Self {
                        #read
                    }
                    unsafe fn set_scalar(self, o: ::lean_rust::runtime::Obj, off: u32) {
                        let #name #pat = self;
                        ::lean_rust::runtime::Model::set_scalar(#v, o, off)
                    }
                    unsafe fn get_scalar(o: ::lean_rust::runtime::Obj, off: u32) -> Self {
                        #read_scalar
                    }
                }
            } else {
                let build = build_ctor(0, &vars, &tys, &params);
                let (layout, reads) = read_fields(&tys, &params);
                let read = construct(quote! { #name }, &s.fields, reads);
                quote! {
                    unsafe fn to_model(self) -> ::lean_rust::runtime::Obj {
                        let #name #pat = self;
                        #build
                    }
                    unsafe fn from_model(o: ::lean_rust::runtime::Obj) -> Self {
                        #layout
                        #read
                    }
                }
            }
        }
        syn::Data::Enum(e) => {
            if e.variants.iter().all(|v| v.fields.is_empty()) {
                let arms = e.variants.iter().enumerate().map(|(i, v)| {
                    let vn = &v.ident;
                    quote! { #i => #name::#vn, }
                });
                let to = e.variants.iter().enumerate().map(|(i, v)| {
                    let vn = &v.ident;
                    quote! { #name::#vn => #i, }
                });
                let arms2 = arms.clone();
                let to2 = to.clone();
                quote! {
                    const SCALAR_SIZE: u32 = 1;
                    unsafe fn to_model(self) -> ::lean_rust::runtime::Obj {
                        ::lean_rust::runtime::lean_box(match self { #(#to)* })
                    }
                    unsafe fn from_model(o: ::lean_rust::runtime::Obj) -> Self {
                        match ::lean_rust::runtime::lean_unbox(o) {
                            #(#arms)*
                            _ => unreachable!("lean_rust::Model: invalid tag"),
                        }
                    }
                    unsafe fn set_scalar(self, o: ::lean_rust::runtime::Obj, off: u32) {
                        ::lean_rust::runtime::lean_ctor_set_uint8(o, off, match self { #(#to2)* } as u8)
                    }
                    unsafe fn get_scalar(o: ::lean_rust::runtime::Obj, off: u32) -> Self {
                        match ::lean_rust::runtime::lean_ctor_get_uint8(o, off) as usize {
                            #(#arms2)*
                            _ => unreachable!("lean_rust::Model: invalid tag"),
                        }
                    }
                }
            } else {
                let mut to_arms = Vec::new();
                let mut from_arms = Vec::new();
                for (i, v) in e.variants.iter().enumerate() {
                    let vn = &v.ident;
                    let tys: Vec<&Type> = v.fields.iter().map(|f| &f.ty).collect();
                    let (pat, vars) = bindings(&v.fields);
                    let build = build_ctor(i, &vars, &tys, &params);
                    to_arms.push(quote! { #name::#vn #pat => #build, });
                    let tag = i as u32;
                    if tys.is_empty() {
                        from_arms.push(quote! { #tag => #name::#vn, });
                    } else {
                        let (layout, reads) = read_fields(&tys, &params);
                        let read = construct(quote! { #name::#vn }, &v.fields, reads);
                        from_arms.push(quote! { #tag => { #layout #read } });
                    }
                }
                quote! {
                    unsafe fn to_model(self) -> ::lean_rust::runtime::Obj {
                        match self { #(#to_arms)* }
                    }
                    unsafe fn from_model(o: ::lean_rust::runtime::Obj) -> Self {
                        let __tag = if ::lean_rust::runtime::lean_is_scalar(o) {
                            ::lean_rust::runtime::lean_unbox(o) as u32
                        } else {
                            ::lean_rust::runtime::lean_obj_tag(o) as u32
                        };
                        match __tag {
                            #(#from_arms)*
                            _ => unreachable!("lean_rust::Model: invalid tag"),
                        }
                    }
                }
            }
        }
        syn::Data::Union(u) => {
            return Err(syn::Error::new_spanned(
                u.union_token,
                "derive(lean_rust::Model): unions are not supported",
            ))
        }
    };
    let mut model_generics = input.generics.clone();
    for p in model_generics.type_params_mut() {
        p.bounds
            .push(syn::parse_quote!(::lean_rust::runtime::Model));
    }
    let (impl_g, ty_g, where_g) = model_generics.split_for_impl();
    let mut spec_generics = input.generics.clone();
    let mut spec_where = spec_generics.make_where_clause().clone();
    let (spec_impl_g, _, _) = input.generics.split_for_impl();
    spec_where
        .predicates
        .push(syn::parse_quote!(Self: ::core::clone::Clone));
    Ok(quote! {
        impl #impl_g ::lean_rust::runtime::Model for #name #ty_g #where_g {
            #body
        }
        impl #spec_impl_g ::lean_rust::spec::SpecArg for #name #ty_g #spec_where {
            type Spec = Self;
            fn spec_arg(&self) -> Self {
                ::core::clone::Clone::clone(self)
            }
        }
    })
}

/* opaque */

fn strategy_of(attr: &ModelAttr, a: &Adapter) -> TokenStream {
    let owned = &a.owned;
    match &attr.strategy {
        Some(p) => {
            let p = deeper(p, 1);
            quote! { #p() }
        }
        None if owned.is_empty() => quote! { ::lean_rust::check::proptest::strategy::Just(()) },
        None if owned.len() == 1 => {
            let t = &owned[0];
            quote! { ::lean_rust::check::proptest::prelude::any::<#t>() }
        }
        None => quote! { (#(::lean_rust::check::proptest::prelude::any::<#owned>()),*) },
    }
}

/// `#[lean_rust::opaque]`: the item, and under `#[cfg(test)]` a proptest comparing the function
/// with its Lean model in `lean/External.lean` (generated by the build script into `rel`): equal
/// results, or a panic of the function where the model fails.
pub fn expand_opaque(
    attr: TokenStream,
    item: TokenStream,
    file: Option<(String, String)>,
) -> syn::Result<TokenStream> {
    let attr = parse_model_args(attr)?;
    if attr.refines.is_some() || attr.requires.is_some() || !attr.ensures.is_empty() {
        return Err(syn::Error::new(
            Span::call_site(),
            "lean_rust::opaque takes only `check` and `strategy`",
        ));
    }
    let Ok(f) = syn::parse2::<syn::ItemFn>(item.clone()) else {
        return Ok(item);
    };
    let receiver = f
        .sig
        .inputs
        .iter()
        .any(|i| matches!(i, syn::FnArg::Receiver(_)));
    let Some((hash, path)) = file else {
        return Ok(item);
    };
    let name = &f.sig.ident;
    let generated = std::path::Path::new(&path)
        .join("lean_rust")
        .join("opaque")
        .join(&hash)
        .join(format!("{name}.rs"));
    let has_model =
        std::fs::read_to_string(&generated).is_ok_and(|t| t.contains("__lean_rust_model"));
    if extracting() || receiver || attr.check == Some(false) || !has_model {
        return Ok(item);
    }
    let sig = signature(&f.sig, None)?;
    let a = adapter(
        &sig,
        quote! { super::#name },
        &Owner {
            self_ty: None,
            trait_: None,
            generics: None,
        },
    );
    let params = &a.params;
    let specs = &a.specs;
    let s = spec_names(&a);
    let call = &a.call;
    let call_stmt = if sig.ret.is_some() {
        quote! { let __r = #call; }
    } else {
        quote! { #call; }
    };
    let value = nested_tuple(&a.results);
    let strategy = strategy_of(&attr, &a);
    let names = &a.names;
    let pat = if names.len() == 1 {
        quote! { #(#names)* }
    } else {
        quote! { (#(#names),*) }
    };
    let pass = &a.pass;
    let include = format!("/lean_rust/opaque/{hash}/{name}.rs");
    let module = format_ident!("__lean_rust_opaque_{}", name);
    Ok(quote! {
        #f
        #[cfg(test)]
        #[allow(dead_code, non_snake_case, unused_mut, unused_imports, unused_variables, clippy::all)]
        mod #module {
            use super::*;
            #[allow(dead_code, non_snake_case, non_camel_case_types, unused_imports, unused_parens, unused_qualifications, unsafe_op_in_unsafe_fn, clippy::all)]
            mod model {
                include!(concat!(env!("OUT_DIR"), #include));
            }
            fn agrees(#(#params),*) -> bool {
                #(#specs)*
                let __rust = ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(move || {
                    #call_stmt
                    #value
                }));
                let __lean = ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(move || {
                    model::__lean_rust_model(#(#s),*)
                }));
                match (__rust, __lean) {
                    (Ok(r), Ok(l)) => r == l,
                    (Err(_), Err(_)) => true,
                    _ => false,
                }
            }
            ::lean_rust::check::proptest::proptest! {
                #[test]
                fn check_model(__args in #strategy) {
                    let #pat = __args;
                    ::lean_rust::check::proptest::prop_assert!(agrees(#(#pass),*));
                }
            }
        }
    })
}
