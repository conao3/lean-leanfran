import LeanPythonEmbed.step09.code.shapes

namespace LeanPythonEmbed.step09.code.report
open LeanPythonEmbed.step09.code.shapes


def totalArea (xs : List Shape) : Nat := (xs.map Shape.area).foldl (· + ·) 0

def largest (xs : List Shape) : Option Shape :=
  xs.foldl (fun best s => match best with
    | none => some s
    | some b => if b.area < s.area then some s else some b) none


end LeanPythonEmbed.step09.code.report
