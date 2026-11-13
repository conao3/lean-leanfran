//! Step 1: Lean definitions called as Rust functions.

leanfran::lean! {
    /// Arithmetic and strings.
    pub mod basics;
    r#"
    def double (n : Nat) : Nat := 2 * n

    def isEven (n : UInt64) : Bool := n % 2 == 0

    def greet (name : String) : String := s!"Hello, {name}!"
    "#
}

#[cfg(test)]
mod tests {
    use super::basics;
    use leanfran::Nat;

    #[test]
    fn double() {
        assert_eq!(basics::double(21u64.into()), Nat::from(42u64));
        let big: Nat = "123456789012345678901234567890".parse().unwrap();
        assert_eq!(
            basics::double(big).to_string(),
            "246913578024691357802469135780"
        );
    }

    #[test]
    fn is_even() {
        assert!(basics::is_even(10));
        assert!(!basics::is_even(7));
    }

    #[test]
    fn greet() {
        assert_eq!(basics::greet("Lean"), "Hello, Lean!");
    }
}
