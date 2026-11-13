//! The obligations of generic functions: the binders of Aeneas's definitions, the law classes,
//! the instances of Aeneas's library and of the crate, the keys `instances` and `obligations`,
//! and the arguments of `exported`.

use leanfran_build::gen::{crate_instance, decl_binders, generic_parts, library_instance, Binder};
use leanfran_build::model::{instance_name, normalize_type, parse_exported, parse_model_args};

const MAX_OF: &str = "def max_of
  {T : Type _} (corecmpOrdInst : core.cmp.Ord T) (coremarkerCopyInst :
  core.marker.Copy T) (a : T) (b : T) :
  Result T
  := do
  let b1 ← corecmpOrdInst.partialOrdInst.ge a b";

#[test]
fn binders_of_a_generic_definition() {
    let b = decl_binders(MAX_OF);
    assert_eq!(
        b,
        vec![
            Binder {
                name: "T".into(),
                ty: "Type _".into(),
                implicit: true
            },
            Binder {
                name: "corecmpOrdInst".into(),
                ty: "core.cmp.Ord T".into(),
                implicit: false
            },
            Binder {
                name: "coremarkerCopyInst".into(),
                ty: "core.marker.Copy T".into(),
                implicit: false
            },
            Binder {
                name: "a".into(),
                ty: "T".into(),
                implicit: false
            },
            Binder {
                name: "b".into(),
                ty: "T".into(),
                implicit: false
            },
        ]
    );
}

#[test]
fn generic_obligations_assume_the_laws_of_the_bounds() {
    let values = vec!["a".to_string(), "b".to_string()];
    let p = generic_parts(&decl_binders(MAX_OF), &values).unwrap();
    assert_eq!(
        p.binders,
        "∀ {T : Type} [LinearOrder T] (corecmpOrdInst : core.cmp.Ord T) [LeanRust.OrdModel corecmpOrdInst] (coremarkerCopyInst : core.marker.Copy T), "
    );
    assert_eq!(p.insts, vec!["corecmpOrdInst", "coremarkerCopyInst"]);
    let eq = "def f {T : Type _} (i : core.cmp.PartialEq T T) (j : core.cmp.PartialOrd T T) (x : T) : Result Bool := ok true";
    let p = generic_parts(&decl_binders(eq), &["x".to_string()]).unwrap();
    assert!(p
        .binders
        .starts_with("∀ {T : Type} [Preorder T] [DecidableRel (α := T) (· ≤ ·)] [DecidableEq T] "));
    let hash = "def f {T : Type _} (i : core.hash.Hash T) (x : T) : Result Bool := ok true";
    assert!(generic_parts(&decl_binders(hash), &["x".to_string()])
        .unwrap_err()
        .contains("per_instance"));
}

#[test]
fn instances_of_aeneas_and_of_the_crate() {
    assert_eq!(
        library_instance("core.cmp.Ord", "u32").as_deref(),
        Some("core.cmp.OrdU32")
    );
    assert_eq!(
        library_instance("core.clone.Clone", "bool").as_deref(),
        Some("core.clone.CloneBool")
    );
    assert_eq!(library_instance("core.cmp.Ord", "bool"), None);
    assert_eq!(library_instance("core.cmp.Ord", "String"), None);
    let funs = "@[reducible]\ndef Id.Insts.CoreCmpOrd : core.cmp.Ord Id := {\n";
    assert_eq!(
        crate_instance(funs, "core.cmp.Ord", "crate::ids::Id").as_deref(),
        Some("Id.Insts.CoreCmpOrd")
    );
    assert_eq!(crate_instance(funs, "core.cmp.PartialEq", "Id"), None);
}

#[test]
fn instances_and_obligations_keys() {
    let a = parse_model_args(quote::quote! {
        instances = [u32, (i64, String)], obligations = per_instance, refines = spec::f
    })
    .unwrap();
    assert!(a.per_instance());
    let labels: Vec<String> = a
        .obligation_labels()
        .into_iter()
        .map(|(l, _, _)| l)
        .collect();
    assert_eq!(labels, vec!["refines.u32", "refines.i64_String"]);
    assert_eq!(instance_name(&syn::parse_quote!(Vec<u32>)), "Vec_u32");
    assert!(parse_model_args(quote::quote! { obligations = sometimes }).is_err());
    let g = parse_model_args(quote::quote! { instances = [u32], ensures(ge = spec::g) }).unwrap();
    assert_eq!(g.obligation_labels()[0].0, "ge");
}

#[test]
fn exported_attributes_of_generic_functions() {
    let a: syn::Attribute = syn::parse_quote! {
        #[::leanfran::exported("m.f", type_params = ["α"], instances = [("rt::Nat", "m.f.inst_Nat"), ("(u32, String)", "m.f.inst_U32_String")])]
    };
    let e = parse_exported(&a).unwrap();
    assert_eq!(e.lean, "m.f");
    assert_eq!(e.type_params, vec!["α"]);
    assert_eq!(e.instances[0], ("rt::Nat".into(), "m.f.inst_Nat".into()));
    let plain: syn::Attribute = syn::parse_quote! { #[leanfran::exported("m.g")] };
    assert_eq!(parse_exported(&plain).unwrap().lean, "m.g");
    assert_eq!(normalize_type("(rt::Nat, String)"), "(Nat,String)");
    assert_eq!(normalize_type("(leanfran::Nat,String)"), "(Nat,String)");
}
