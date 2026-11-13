/-! # S-expressions for the emitted Clojure source

The emitter builds Clojure code as `Sx` trees and renders them with a small
layout algorithm: a form that fits on the line is printed flat, otherwise its
arguments go on their own lines. Binding vectors and `case` clauses are laid
out in pairs. -/

namespace LeanClj

inductive Sx where
  | atom (s : String)
  | list (xs : List Sx)
  | vec (xs : List Sx)
  | map (xs : List Sx)
  deriving Inhabited

namespace Sx

def width : Nat := 100

partial def flat : Sx → String
  | .atom s => s
  | .list xs => "(" ++ " ".intercalate (xs.map flat) ++ ")"
  | .vec xs => "[" ++ " ".intercalate (xs.map flat) ++ "]"
  | .map xs => "{" ++ " ".intercalate (xs.map flat) ++ "}"

def spaces (n : Nat) : String := String.ofList (List.replicate n ' ')

def pairs : List Sx → List (Sx × Option Sx)
  | [] => []
  | [a] => [(a, none)]
  | a :: b :: rest => (a, some b) :: pairs rest

/-- Pack atoms greedily into lines starting at column `ind`. -/
def fill (ind : Nat) (xs : List Sx) : String := Id.run do
  let mut acc := ""
  let mut col := ind
  let mut first := true
  for x in xs do
    let f := x.flat
    if first then
      acc := f; col := ind + f.length; first := false
    else if col + 1 + f.length ≤ width then
      acc := acc ++ " " ++ f; col := col + 1 + f.length
    else
      acc := acc ++ "\n" ++ spaces ind ++ f; col := ind + f.length
  return acc

mutual

partial def render (ind : Nat) (sx : Sx) : String :=
  let f := sx.flat
  if f.length + ind ≤ width then f
  else
    match sx with
    | .atom s => s
    | .vec xs =>
      if xs.all (fun | .atom _ => true | _ => false) then "[" ++ fill (ind + 1) xs ++ "]"
      else "[" ++ renderLines (ind + 1) xs ++ "]"
    | .map xs => "{" ++ renderPairs (ind + 1) xs ++ "}"
    | .list [] => "()"
    | .list (h :: t) =>
      let hs := h.flat
      match hs, t with
      | "let", bs :: body | "loop", bs :: body | "letfn", bs :: body =>
        let bInd := ind + hs.length + 2
        "(" ++ hs ++ " " ++ renderBindings bInd bs ++ renderTail (ind + 2) body ++ ")"
      | "defn", name :: args :: body | "defn-", name :: args :: body =>
        "(" ++ hs ++ " " ++ name.flat ++ " " ++ args.flat ++ renderTail (ind + 2) body ++ ")"
      | "def", name :: body =>
        "(" ++ hs ++ " " ++ name.flat ++ renderTail (ind + 2) body ++ ")"
      | "case", scrut :: clauses =>
        "(" ++ hs ++ " " ++ scrut.render (ind + hs.length + 2) ++ renderClauses (ind + 2) clauses ++ ")"
      | "fn", args :: body | "delay", args :: body =>
        "(" ++ hs ++ " " ++ args.render (ind + hs.length + 2) ++ renderTail (ind + 2) body ++ ")"
      | "do", body =>
        "(" ++ hs ++ renderTail (ind + 2) body ++ ")"
      | _, [] => "(" ++ hs ++ ")"
      | _, a :: rest =>
        let aInd := ind + hs.length + 2
        let first := a.render aInd
        "(" ++ hs ++ " " ++ first ++ renderTail aInd rest ++ ")"

partial def renderLines (ind : Nat) (xs : List Sx) : String :=
  ("\n" ++ spaces ind).intercalate (xs.map (render ind))

partial def renderTail (ind : Nat) (xs : List Sx) : String :=
  String.join (xs.map fun x => "\n" ++ spaces ind ++ x.render ind)

partial def renderBindings (ind : Nat) : Sx → String
  | .vec xs =>
    let ls := (pairs xs).map fun
      | (n, some v) =>
        let nf := n.flat
        nf ++ " " ++ v.render (ind + 1 + nf.length + 1)
      | (n, none) => n.flat
    "[" ++ ("\n" ++ spaces (ind + 1)).intercalate ls ++ "]"
  | sx => sx.render ind

partial def renderClauses (ind : Nat) (xs : List Sx) : String :=
  String.join <| (pairs xs).map fun
    | (k, some v) =>
      let kf := k.flat
      let one := kf ++ " " ++ v.flat
      if one.length + ind ≤ width then "\n" ++ spaces ind ++ one
      else "\n" ++ spaces ind ++ kf ++ "\n" ++ spaces (ind + 2) ++ v.render (ind + 2)
    | (d, none) => "\n" ++ spaces ind ++ d.render ind

partial def renderPairs (ind : Nat) (xs : List Sx) : String :=
  ("\n" ++ spaces ind).intercalate <| (pairs xs).map fun
    | (k, some v) => let kf := k.flat; kf ++ " " ++ v.render (ind + kf.length + 1)
    | (k, none) => k.flat

end

end Sx

end LeanClj
