//! Generated code on `wasm32-unknown-unknown`: `run` checks pure functions, a panic and an `IO`
//! action, and returns the bits of the failed checks (0 when all pass). `tests/wasm/test.sh` calls
//! it in node, and the test of the crate calls it natively.

lean_rust::lean! {
    pub mod funcs;
    r#"
    def fib : Nat → Nat
      | 0 => 0
      | 1 => 1
      | n + 2 => fib n + fib (n + 1)
    decreasing_by all_goals omega

    def fastFib (n : Nat) : Nat := Id.run do
      let mut (a, b) := (0, 1)
      for _ in [0:n] do
        (a, b) := (b, a + b)
      return a

    def greet (names : List String) : String :=
      ", ".intercalate (names.map (s!"Hello, {·}!"))

    def sortDesc (xs : Array Int) : Array Int := xs.qsort (· > ·)

    def headOr (xs : List Nat) : Nat := xs.head!

    def addInt (a b : Int) : Int := a + b

    def mix (x : UInt64) : UInt64 := x * 0x9e3779b97f4a7c15 + 1

    def half (x : Float) : String := toString (x / 2)

    def readFile (path : String) : IO String := IO.FS.readFile path
    "#
}

/// The bits of the failed checks.
pub fn failures() -> u32 {
    use lean_rust::{Int, Nat};
    let checks = [
        funcs::fib(Nat::from(20u64)) == Nat::from(6765u64),
        funcs::fast_fib(Nat::from(100u64)).to_string() == "354224848179261915075",
        funcs::greet(vec!["Lean".into(), "Rust".into()]) == "Hello, Lean!, Hello, Rust!",
        funcs::sort_desc(vec![Int::from(3i64), Int::from(-1i64), Int::from(7i64)])
            == vec![Int::from(7i64), Int::from(3i64), Int::from(-1i64)],
        funcs::head_or(vec![]) == Nat::from(0u64),
        funcs::add_int(Int::from(-(1i64 << 30)), Int::from(-1i64)) == Int::from(-(1i64 << 30) - 1),
        funcs::add_int(Int::from((1i64 << 30) - 1), Int::from(1i64)) == Int::from(1i64 << 30),
        funcs::add_int(Int::from(-7i64), Int::from(3i64)) == Int::from(-4i64),
        funcs::mix(u64::MAX) == u64::MAX.wrapping_mul(0x9e3779b97f4a7c15).wrapping_add(1),
        funcs::half(5.0) == "2.500000",
        match funcs::read_file("/nonexistent/lean-rust-wasm-test") {
            Err(e) if cfg!(target_family = "wasm") => {
                e.kind() == std::io::ErrorKind::Unsupported
                    && e.to_string()
                        .contains("not supported on wasm32-unknown-unknown")
            }
            Err(e) => e.kind() == std::io::ErrorKind::NotFound,
            Ok(_) => false,
        },
    ];
    checks
        .iter()
        .enumerate()
        .filter(|(_, ok)| !**ok)
        .map(|(i, _)| 1 << i)
        .sum()
}

#[no_mangle]
pub extern "C" fn run() -> u32 {
    failures()
}

#[cfg(test)]
mod tests {
    #[test]
    fn all_checks_pass() {
        assert_eq!(super::failures(), 0);
    }
}
