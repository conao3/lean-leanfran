//! Step 7: `IO` actions are Rust functions returning `std::io::Result`.

lean_rust::lean! {
    /// Files, processes, mutable references and errors.
    pub mod actions;
    r#"
    def appendLine (path line : String) : IO Unit := do
      let h ← IO.FS.Handle.mk path .append
      h.putStrLn line

    def countLines (path : String) : IO Nat := do
      return (← IO.FS.lines path).size

    def runEcho (word : String) : IO String := do
      return (← IO.Process.run { cmd := "echo", args := #[word] }).trimAsciiEnd.toString

    def countTo (n : Nat) : IO Nat := do
      let r ← IO.mkRef 0
      for _ in [0:n] do
        r.modify (· + 1)
      r.get

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
    fn files() {
        let dir = std::env::temp_dir().join(format!("step-07-io-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("notes.txt");
        let path = path.to_str().unwrap();
        actions::append_line(path, "one").unwrap();
        actions::append_line(path, "two").unwrap();
        assert_eq!(actions::count_lines(path).unwrap(), Nat::from(2u64));
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn processes() {
        assert_eq!(actions::run_echo("hello").unwrap(), "hello");
    }

    #[test]
    fn refs() {
        assert_eq!(actions::count_to(Nat::from(5u64)).unwrap(), Nat::from(5u64));
    }

    #[test]
    fn errors() {
        let e = actions::count_lines("/nonexistent/step-07-io").unwrap_err();
        assert_eq!(e.kind(), std::io::ErrorKind::NotFound);
        assert_eq!(
            e.to_string(),
            "no such file or directory (error code: 2)\n  file: /nonexistent/step-07-io"
        );
        assert_eq!(actions::check_positive(Int::from(3)).unwrap(), Int::from(3));
        let e = actions::check_positive(Int::from(-1)).unwrap_err();
        assert_eq!(e.to_string(), "not positive: -1");
    }
}
