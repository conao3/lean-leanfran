//! Prints `LeanRust/RuntimeExterns.lean` (`make gen-externs`).

fn main() {
    print!("{}", leanfran_runtime::runtime_externs_lean());
}
