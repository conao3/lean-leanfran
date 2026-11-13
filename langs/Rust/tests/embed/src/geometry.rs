//! A `lean!` block in a module file, used by `crate::scaled`.

leanfran::lean! {
    pub mod shapes;
    r#"
    structure Point where
      x : Nat
      y : Nat
      deriving DecidableEq

    def Point.manhattan (p : Point) : Nat := p.x + p.y
    "#
}
