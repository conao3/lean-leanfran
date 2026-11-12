import Std.Data.HashMap
namespace count

def wordChar (c : Char) : Bool := c.isAlphanum || c == '\''

def words (text : String) : List String :=
  ((text.splitToList (fun c => !wordChar c)).map String.toLower).filter (!·.isEmpty)

private def frequencies (ws : List String) : Std.HashMap String Nat := Id.run do
  let mut m := {}
  for w in ws do
    m := m.insert w (m.getD w 0 + 1)
  return m

def topWords (n : Nat) (text : String) : List (String × Nat) :=
  ((frequencies (words text)).toArray.qsort
    (fun a b => a.2 > b.2 || (a.2 == b.2 && a.1 < b.1))).toList.take n

theorem topWords_at_most (n : Nat) (text : String) : (topWords n text).length ≤ n := by
  simp [topWords]
  omega

end count
