//! Step 7: `IO` actions are Rust functions returning `std::io::Result`.

lean_rust::lean! {
    /// Actions with mutable references, the standard output and errors.
    pub mod actions;
    r#"
    def countTo (n : Nat) : IO Nat := do
      let r ← IO.mkRef 0
      for _ in [0:n] do
        r.modify (· + 1)
      r.get

    def report (name : String) (score : Nat) : IO Unit :=
      IO.println s!"{name}: {score}"

    def checkPositive (n : Int) : IO Int := do
      if n ≤ 0 then throw (IO.userError s!"not positive: {n}")
      return n
    "#
}

#[cfg(test)]
mod tests {
    use super::actions;
    use lean_rust::{Int, Nat};

    #[test]
    fn refs() {
        assert_eq!(actions::count_to(Nat::from(5u64)).unwrap(), Nat::from(5u64));
    }

    #[test]
    fn stdout() {
        actions::report("lean", Nat::from(3u64)).unwrap();
    }

    #[test]
    fn errors() {
        assert_eq!(actions::check_positive(Int::from(3)).unwrap(), Int::from(3));
        let e = actions::check_positive(Int::from(-1)).unwrap_err();
        assert_eq!(e.to_string(), "not positive: -1");
    }
}
