//! Prints `LeanRust/RuntimeExterns.lean` (`make gen-externs`).

fn main() {
    print!("{}", lean_rust_runtime::runtime_externs_lean());
}
