import LeanRustGen.Lib.Instances
namespace generic

def countOf {α : Type} [BEq α] (xs : List α) (x : α) : Nat := xs.countP (· == x)

rust_instances countOf [Nat, String]

end generic
