//! Step 4: a Lean inductive type is a Rust enum.

leanfran::lean! {
    /// Shapes, colours and a binary search tree.
    pub mod shapes;
    r#"
    inductive Color where
      | red | green | blue
      deriving DecidableEq

    def Color.next : Color → Color
      | .red => .green
      | .green => .blue
      | .blue => .red

    inductive Shape where
      | circle (r : Nat)
      | rect (w h : Nat)
      deriving DecidableEq

    /-- The area, with π taken as 3. -/
    def Shape.area : Shape → Nat
      | .circle r => 3 * r * r
      | .rect w h => w * h

    inductive Tree where
      | leaf
      | node (l : Tree) (v : Nat) (r : Tree)
      deriving DecidableEq

    def Tree.insert (t : Tree) (x : Nat) : Tree :=
      match t with
      | .leaf => .node .leaf x .leaf
      | .node l v r =>
        if x < v then .node (l.insert x) v r
        else if v < x then .node l v (r.insert x)
        else t

    def Tree.toList : Tree → List Nat
      | .leaf => []
      | .node l v r => l.toList ++ [v] ++ r.toList

    def Tree.ofList (xs : List Nat) : Tree := xs.foldl Tree.insert .leaf
    "#
}

#[cfg(test)]
mod tests {
    use super::shapes::{self, Color, Shape, Tree};
    use leanfran::Nat;

    fn n(x: u64) -> Nat {
        Nat::from(x)
    }

    #[test]
    fn colors() {
        assert_eq!(shapes::color_next(Color::Blue), Color::Red);
    }

    #[test]
    fn area() {
        assert_eq!(shapes::shape_area(Shape::Circle { r: n(2) }), n(12));
        assert_eq!(shapes::shape_area(Shape::Rect { w: n(3), h: n(4) }), n(12));
    }

    #[test]
    fn tree() {
        let t = shapes::tree_of_list(vec![n(5), n(2), n(8), n(2)]);
        assert_eq!(shapes::tree_to_list(t.clone()), vec![n(2), n(5), n(8)]);
        let Tree::Node { v, .. } = t else {
            panic!("a leaf")
        };
        assert_eq!(v, n(5));
    }
}
