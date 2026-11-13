//! `LeanRust/RuntimeExterns.lean` lists exactly the names of `EXTERNS`.

#[test]
fn runtime_externs_lean_is_up_to_date() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../LeanRust/RuntimeExterns.lean"
    );
    let on_disk = std::fs::read_to_string(path).expect("read LeanRust/RuntimeExterns.lean");
    assert!(
        on_disk == leanfran_runtime::runtime_externs_lean(),
        "LeanRust/RuntimeExterns.lean is out of date: run `make gen-externs`"
    );
}

#[test]
fn externs_are_sorted_and_unique() {
    let e = leanfran_runtime::EXTERNS;
    assert!(e.windows(2).all(|w| w[0] < w[1]));
    for name in [
        "lean_nat_add",
        "lean_apply_1",
        "lean_string_append",
        "sqrt",
        "sqrtf",
        "lean_get_stdout",
    ] {
        assert!(e.contains(&name), "{name} missing");
    }
}
