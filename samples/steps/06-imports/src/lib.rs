//! Step 6: importing Lean modules into a block, and `do` notation.

lean_rust::lean! {
    /// Duplicates in a list, found with a hash set.
    #[lean(imports = ["Std.Data.HashSet"])]
    pub mod dedup;
    r#"
    def dedup (xs : List String) : List String := Id.run do
      let mut seen : Std.HashSet String := {}
      let mut out := #[]
      for x in xs do
        unless seen.contains x do
          seen := seen.insert x
          out := out.push x
      return out.toList

    def duplicates (xs : List String) : List String := Id.run do
      let mut seen : Std.HashSet String := {}
      let mut dups : Std.HashSet String := {}
      for x in xs do
        if seen.contains x then dups := dups.insert x else seen := seen.insert x
      return xs.filter dups.contains |> dedup
    "#
}

#[cfg(test)]
mod tests {
    use super::dedup;

    fn strings(xs: &[&str]) -> Vec<String> {
        xs.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn dedup() {
        assert_eq!(
            dedup::dedup(strings(&["b", "a", "b", "c", "a"])),
            strings(&["b", "a", "c"])
        );
    }

    #[test]
    fn duplicates() {
        assert_eq!(
            dedup::duplicates(strings(&["b", "a", "b", "c", "a"])),
            strings(&["b", "a"])
        );
    }
}
