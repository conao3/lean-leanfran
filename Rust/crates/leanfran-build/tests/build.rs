//! Cache keys, file hashes and the Lean files of `lean!` blocks.

use leanfran_build::syntax::file_hash;
use leanfran_build::{
    cache_keys, lean_source, Block, AENEAS_MODEL_LEAN, INSTANCES_LEAN, INSTANCES_MODULE,
    LEAN_TOOLCHAIN,
};

fn block(name: &str, source: &str, uses: Vec<Vec<String>>) -> Block {
    Block {
        file: "src/lib.rs".into(),
        file_hash: file_hash("src/lib.rs"),
        name: name.into(),
        path: vec![name.into()],
        imports: vec![],
        uses,
        source: source.into(),
        line: 3,
    }
}

#[test]
fn file_hash_is_16_hex_digits_of_sha256() {
    assert_eq!(file_hash("src/lib.rs").len(), 16);
    assert_eq!(file_hash(""), "e3b0c44298fc1c14");
}

#[test]
fn toolchain_matches_the_repository() {
    let repo = include_str!("../../../lean-toolchain");
    assert_eq!(repo.trim(), LEAN_TOOLCHAIN);
}

#[test]
fn cache_keys_follow_sources_and_uses() {
    let a = block("a", "def x := 1", vec![]);
    let b = block("b", "def y := x", vec![vec!["a".into()]]);
    let k1 = cache_keys("c", &[a.clone(), b.clone()], "").unwrap();
    let a2 = block("a", "def x := 2", vec![]);
    let k2 = cache_keys("c", &[a2, b.clone()], "").unwrap();
    assert_ne!(k1[0], k2[0]);
    assert_ne!(k1[1], k2[1]);
    assert_ne!(
        cache_keys("d", &[a.clone(), b.clone()], "").unwrap()[0],
        k1[0]
    );
    assert_ne!(
        cache_keys("c", &[a.clone(), b.clone()], "csimp").unwrap()[0],
        k1[0]
    );
    let cyclic = block("a", "", vec![vec!["b".into()]]);
    assert!(cache_keys("c", &[cyclic, b], "").is_err());
    assert!(cache_keys("c", &[block("z", "", vec![vec!["nope".into()]])], "").is_err());
}

#[test]
fn lean_source_wraps_and_dedents() {
    let a = block("shapes", "", vec![]);
    let mut b = block(
        "arith",
        "\n    def double (n : Nat) : Nat :=\n      n + n\n    ",
        vec![],
    );
    b.imports = vec!["Std.Data.HashMap".into()];
    let (text, header, indent) = lean_source(&b, &[&a], "my_crate");
    assert_eq!(
        text,
        "import Std.Data.HashMap\nimport LeanRustGen.Embed.my_crate.hfbaf8ad0a25a7f04.shapes\nopen shapes\nnamespace arith\n\ndef double (n : Nat) : Nat :=\n  n + n\n\nend arith\n"
            .replace("fbaf8ad0a25a7f04", &file_hash("src/lib.rs"))
    );
    assert_eq!(header, 4);
    assert_eq!(indent, 4);
}

#[test]
fn lean_library_matches_the_repository() {
    assert_eq!(
        include_str!("../../../LeanRust/Instances.lean"),
        INSTANCES_LEAN
    );
    assert_eq!(
        include_str!("../../../LeanRust/AeneasModel.lean"),
        AENEAS_MODEL_LEAN
    );
}

#[test]
fn blocks_using_rust_instances_import_the_command() {
    let b = block(
        "g",
        "def f {α} (x : α) := x\nrust_instances f [Nat]",
        vec![],
    );
    let (text, header, _) = lean_source(&b, &[], "my_crate");
    assert!(text.starts_with(&format!("import {INSTANCES_MODULE}\n")));
    assert_eq!(header, 2);
    let plain = block("g", "def f {α} (x : α) := x", vec![]);
    assert!(!lean_source(&plain, &[], "my_crate").0.contains("import"));
    assert_ne!(
        cache_keys("c", &[b], "").unwrap(),
        cache_keys("c", &[plain], "").unwrap()
    );
}
