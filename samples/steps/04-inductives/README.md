# 04-inductives

A Lean inductive type is a generated Rust enum.

| Lean | Rust |
|---|---|
| `inductive Color \| red \| green \| blue` | `enum Color { Red, Green, Blue }` (field-less) |
| `inductive Shape \| circle (r : Nat) \| rect (w h : Nat)` | `enum Shape { Circle { r: Nat }, Rect { w: Nat, h: Nat } }` |
| `inductive Tree \| leaf \| node (l : Tree) (v : Nat) (r : Tree)` | `enum Tree { Leaf, Node { l: Box<Tree>, v: Nat, r: Box<Tree> } }` |

Recursive fields are boxed. `Tree.insert` and `Tree.toList` build and walk a binary search
tree; the tests match on the generated enum.

Next: [05-collections](../05-collections).
