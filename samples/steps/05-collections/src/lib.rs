//! Step 5: lists, arrays, options, errors and pairs.

lean_rust::lean! {
    /// Functions over collections.
    pub mod collections;
    r#"
    def evens (xs : List Nat) : List Nat := xs.filter (· % 2 == 0)

    def indexed (xs : Array String) : List (Nat × String) := xs.toList.zipIdx.map fun (s, i) => (i, s)

    def firstLong (xs : List String) (n : Nat) : Option String := xs.find? (·.length ≥ n)

    def safeDiv (a b : Int) : Except String Int :=
      if b == 0 then .error "division by zero" else .ok (a / b)
    "#
}

#[cfg(test)]
mod tests {
    use super::collections;
    use lean_rust::{Int, Nat};

    fn n(x: u64) -> Nat {
        Nat::from(x)
    }

    #[test]
    fn lists() {
        assert_eq!(
            collections::evens(vec![n(1), n(2), n(3), n(4)]),
            vec![n(2), n(4)]
        );
    }

    #[test]
    fn pairs() {
        let xs = vec!["a".to_string(), "b".to_string()];
        assert_eq!(
            collections::indexed(xs),
            vec![(n(0), "a".to_string()), (n(1), "b".to_string())]
        );
    }

    #[test]
    fn options() {
        let xs = vec!["hi".to_string(), "hello".to_string()];
        assert_eq!(
            collections::first_long(xs.clone(), n(3)),
            Some("hello".to_string())
        );
        assert_eq!(collections::first_long(xs, n(9)), None);
    }

    #[test]
    fn errors() {
        assert_eq!(
            collections::safe_div(Int::from(7), Int::from(2)),
            Ok(Int::from(3))
        );
        assert_eq!(
            collections::safe_div(Int::from(7), Int::from(0)),
            Err("division by zero".to_string())
        );
    }
}
