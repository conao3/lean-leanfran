//! Step 3: a Lean structure is a Rust struct.

leanfran::lean! {
    /// Points on the integer grid.
    pub mod geometry;
    r#"
    structure Point where
      x : Int
      y : Int
      deriving DecidableEq

    def Point.add (p q : Point) : Point := ⟨p.x + q.x, p.y + q.y⟩

    def Point.manhattan (p : Point) : Nat := p.x.natAbs + p.y.natAbs

    def origin : Point := ⟨0, 0⟩

    theorem Point.add_origin (p : Point) : p.add origin = p := by
      simp [Point.add, origin]
    "#
}

#[cfg(test)]
mod tests {
    use super::geometry::{self, Point};
    use leanfran::{Int, Nat};

    fn pt(x: i64, y: i64) -> Point {
        Point {
            x: Int::from(x),
            y: Int::from(y),
        }
    }

    #[test]
    fn add() {
        assert_eq!(geometry::point_add(pt(1, -2), pt(3, 4)), pt(4, 2));
        assert_eq!(geometry::point_add(pt(5, 6), geometry::origin()), pt(5, 6));
    }

    #[test]
    fn manhattan() {
        assert_eq!(geometry::point_manhattan(pt(-3, 4)), Nat::from(7u64));
    }
}
