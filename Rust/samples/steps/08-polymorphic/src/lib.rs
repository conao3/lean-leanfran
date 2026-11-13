//! Step 8: a polymorphic Lean function as a generic Rust function.

leanfran::lean! {
    /// The largest element, for the types chosen with `rust_instances`.
    pub mod sorting;
    r#"
    def largest {α : Type} [Ord α] [Inhabited α] (xs : List α) : α :=
      xs.foldl (fun a b => if compare a b == .lt then b else a) default

    rust_instances largest [Nat, String]
    "#
}

#[cfg(test)]
mod tests {
    use super::sorting;
    use leanfran::Nat;

    #[test]
    fn generic() {
        assert_eq!(
            sorting::largest(vec![Nat::from(3u64), Nat::from(9u64), Nat::from(4u64)]),
            Nat::from(9u64)
        );
        assert_eq!(
            sorting::largest(vec!["pear".to_string(), "apple".to_string()]),
            "pear"
        );
    }

    #[test]
    fn instantiations() {
        assert_eq!(sorting::largest_inst_string(vec![]), "");
    }
}
