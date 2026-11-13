//! Runs `LeanRustTest.Vectors.report` through the generated Rust (diff test against the C backend oracle).

mod generated {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../test-out/vectors.rs"
    ));
}

fn main() {
    unsafe {
        let s = generated::l_LeanRustTest_Vectors_report(leanfran_runtime::lean_box(0));
        println!("{}", leanfran_runtime::lean_string_to_str(s));
    }
}
