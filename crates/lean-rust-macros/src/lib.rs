//! Procedural macros of lean-rust.
//!
//! `lean!` expands to a module that includes the Rust code the build script generated from the
//! Lean source: `include!(concat!(env!("OUT_DIR"), "/lean_rust/<file hash>/<name>.rs"))`. It
//! does not run Lean. The macro reads `OUT_DIR` and reports a missing build script or a
//! missing generated file with `compile_error!`.

use lean_rust_build::syntax::{file_hash, normalize_path, LeanBlock};
use proc_macro::TokenStream;
use quote::quote;
use std::path::{Path, PathBuf};
use syn::parse_macro_input;

/// Marks a generated public function with the full name of the Lean definition it runs. It
/// changes nothing; tools read it to map Rust paths to Lean names.
#[proc_macro_attribute]
pub fn exported(_attr: TokenStream, item: TokenStream) -> TokenStream {
    item
}

/// Lean source checked and compiled by the build script.
///
/// ```ignore
/// lean_rust::lean! {
///     /// Documentation of the module.
///     #[lean(imports = ["Std.Data.HashMap"], uses = [crate::geometry::shapes])]
///     pub mod arith;
///     r#"
///     def double (n : Nat) : Nat := n + n
///     "#
/// }
/// ```
#[proc_macro]
pub fn lean(input: TokenStream) -> TokenStream {
    let block = parse_macro_input!(input as LeanBlock);
    match expand(&block) {
        Ok(ts) => ts,
        Err(msg) => {
            let name = &block.name;
            let vis = &block.vis;
            quote! {
                #vis mod #name {
                    ::core::compile_error!(#msg);
                }
            }
            .into()
        }
    }
}

fn caller_rel_path() -> Result<String, String> {
    let file = proc_macro::Span::call_site()
        .local_file()
        .ok_or("lean!: the source file of the macro call is unknown")?;
    let manifest = std::env::var_os("CARGO_MANIFEST_DIR")
        .map(PathBuf::from)
        .ok_or("lean!: CARGO_MANIFEST_DIR is not set (build with cargo)")?;
    let abs = if file.is_absolute() {
        file
    } else {
        std::env::current_dir()
            .map_err(|e| format!("lean!: {e}"))?
            .join(file)
    };
    let abs = abs.canonicalize().unwrap_or(abs);
    let manifest = manifest.canonicalize().unwrap_or(manifest);
    let rel = abs.strip_prefix(&manifest).map_err(|_| {
        format!(
            "lean!: {} is not inside the crate {}",
            abs.display(),
            manifest.display()
        )
    })?;
    Ok(normalize_path(rel))
}

fn expand(block: &LeanBlock) -> Result<TokenStream, String> {
    let rel = caller_rel_path()?;
    let hash = file_hash(&rel);
    let name = &block.name;
    let file_name = format!("/{name}.rs");
    let Some(out_dir) = std::env::var_os("OUT_DIR") else {
        return Err("lean!: the crate has no build script. Add `build.rs` with \
             `fn main() { lean_rust_build::Builder::new().compile().unwrap(); }` and \
             `lean-rust-build` to [build-dependencies]"
            .to_string());
    };
    let generated = Path::new(&out_dir)
        .join("lean_rust")
        .join(&hash)
        .join(format!("{name}.rs"));
    if !generated.is_file() {
        return Err(format!(
            "lean!: {} was not generated for `mod {name}` in {rel}. The build script must call \
             `lean_rust_build::Builder::new().compile()`, which generates the lean! blocks of src/**/*.rs",
            generated.display()
        ));
    }
    let attrs = &block.attrs;
    let vis = &block.vis;
    Ok(quote! {
        #(#attrs)*
        #[allow(dead_code, non_snake_case, non_camel_case_types, unused_imports, unused_parens, clippy::all)]
        #vis mod #name {
            include!(concat!(env!("OUT_DIR"), "/lean_rust/", #hash, #file_name));
        }
    }
    .into())
}
