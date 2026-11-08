//! The syntax of `lean!`, shared by the macro and the build script.

use sha2::{Digest, Sha256};
use syn::parse::{Parse, ParseStream};
use syn::punctuated::Punctuated;
use syn::{bracketed, Attribute, Ident, LitStr, Path, Token, Visibility};

/// A `lean!` block:
///
/// ```text
/// /// documentation
/// #[lean(imports = ["Std.Data.HashMap"], uses = [crate::geometry::shapes])]
/// pub mod name;
/// r#"Lean source"#
/// ```
pub struct LeanBlock {
    /// The attributes other than `#[lean(...)]` (documentation), put on the module.
    pub attrs: Vec<Attribute>,
    pub imports: Vec<String>,
    pub uses: Vec<Path>,
    pub vis: Visibility,
    pub name: Ident,
    pub source: LitStr,
}

impl Parse for LeanBlock {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let all = input.call(Attribute::parse_outer)?;
        let mut attrs = Vec::new();
        let mut imports = Vec::new();
        let mut uses = Vec::new();
        for attr in all {
            if !attr.path().is_ident("lean") {
                attrs.push(attr);
                continue;
            }
            attr.parse_nested_meta(|meta| {
                let content;
                if meta.path.is_ident("imports") {
                    let value = meta.value()?;
                    bracketed!(content in value);
                    let lits = Punctuated::<LitStr, Token![,]>::parse_terminated(&content)?;
                    imports.extend(lits.iter().map(LitStr::value));
                    Ok(())
                } else if meta.path.is_ident("uses") {
                    let value = meta.value()?;
                    bracketed!(content in value);
                    let paths = Punctuated::<Path, Token![,]>::parse_terminated(&content)?;
                    uses.extend(paths);
                    Ok(())
                } else {
                    Err(meta.error("expected `imports` or `uses`"))
                }
            })?;
        }
        let vis: Visibility = input.parse()?;
        input.parse::<Token![mod]>()?;
        let name: Ident = input.parse()?;
        input.parse::<Token![;]>()?;
        let source: LitStr = input.parse()?;
        if !input.is_empty() {
            return Err(input.error("unexpected tokens after the Lean source"));
        }
        Ok(LeanBlock {
            attrs,
            imports,
            uses,
            vis,
            name,
            source,
        })
    }
}

/// The first 16 hex digits of the SHA-256 of `rel_path` (the path of a Rust file relative to
/// the crate root, with `/` separators): the directory of the file's blocks in `OUT_DIR`.
pub fn file_hash(rel_path: &str) -> String {
    let digest = Sha256::digest(rel_path.as_bytes());
    digest.iter().take(8).map(|b| format!("{b:02x}")).collect()
}

/// `rel_path` with `/` separators.
pub fn normalize_path(rel_path: &std::path::Path) -> String {
    rel_path
        .components()
        .map(|c| c.as_os_str().to_string_lossy().into_owned())
        .collect::<Vec<_>>()
        .join("/")
}
