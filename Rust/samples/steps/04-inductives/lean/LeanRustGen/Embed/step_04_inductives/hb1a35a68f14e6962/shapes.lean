namespace shapes

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

end shapes
