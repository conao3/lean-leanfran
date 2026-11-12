# 03-structures

A Lean structure is a generated Rust struct with snake_case fields; it derives `Debug`,
`Clone` and `PartialEq`, plus `Eq` and `Hash` with `deriving DecidableEq`.

```lean
structure Point where
  x : Int
  y : Int
  deriving DecidableEq

def Point.add (p q : Point) : Point := ⟨p.x + q.x, p.y + q.y⟩
```

```rust
use geometry::Point;

let p = Point { x: Int::from(1), y: Int::from(-2) };
assert_eq!(geometry::point_add(p.clone(), geometry::origin()), p);
```

`Point.add` is `point_add`: the name is the Lean name relative to the block's namespace, in
snake_case. A definition without arguments (`origin`) is a function without arguments.

Next: [04-inductives](../04-inductives).
