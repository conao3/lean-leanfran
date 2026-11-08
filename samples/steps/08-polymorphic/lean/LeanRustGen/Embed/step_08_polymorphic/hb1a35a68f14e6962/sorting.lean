import LeanRustGen.Lib.Instances
namespace sorting

def largest {α : Type} [Ord α] [Inhabited α] (xs : List α) : α :=
  xs.foldl (fun a b => if compare a b == .lt then b else a) default

rust_instances largest [Nat, String]

end sorting
