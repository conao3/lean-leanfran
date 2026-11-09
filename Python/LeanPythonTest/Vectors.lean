import Std.Data.HashMap
import LeanPythonTest.Basic

/-! Test vectors shared by the native oracle and the generated Python.

`report` renders every case with Lean's own `Repr`/`toString`, so both
backends must print the same text. -/

namespace LeanPythonTest.Vectors

open LeanPythonTest.Basic

structure Mixed where
  label : String
  flag : Bool
  small : UInt8
  wide : UInt16
  word : UInt64
  ratio : Float
  deriving Repr

def mkMixed (n : Nat) : Mixed :=
  { label := s!"m{n}", flag := n % 2 == 0, small := n.toUInt8 + 250, wide := n.toUInt16 * 1000,
    word := n.toUInt64 * 0xFFFFFFFFFFFF, ratio := n.toFloat / 3.0 }

inductive Shape where
  | circle (r : Nat)
  | rect (w h : Nat)
  | dot
  deriving Repr, BEq

def area : Shape → Nat
  | .circle r => 3 * r * r
  | .rect w h => w * h
  | .dot => 0

inductive Color where
  | red | green | blue
  deriving Repr, BEq, DecidableEq

def Color.next : Color → Color
  | .red => .green
  | .green => .blue
  | .blue => .red

def fact : Nat → Nat
  | 0 => 1
  | n + 1 => (n + 1) * fact n

def fib (n : Nat) : Nat := Id.run do
  let mut a := 0
  let mut b := 1
  for _ in [0:n] do
    (a, b) := (b, a + b)
  return a

def adder (k : Nat) : Nat → Nat := fun x => x + k

def applyTwice (f : α → α) (x : α) : α := f (f x)

def curry3 (a b c : Nat) : Nat := a * 100 + b * 10 + c

def partials : List Nat :=
  let f := curry3 1
  let g := f 2
  [g 3, (curry3 4 5) 6, applyTwice (adder 7) 1, (List.map (curry3 0 0) [1, 2]).sum].foldl (· + ·) 0 :: [List.length [f, curry3 2]]

def wordFreq (s : String) : List (String × Nat) :=
  let m : Std.HashMap String Nat := (s.splitOn " ").foldl (fun m w => m.insert w (m.getD w 0 + 1)) {}
  (m.toList.toArray.qsort (fun a b => a.1 < b.1)).toList

def unicode : List String :=
  let s := "aé日本🎉z"
  [toString s.length, toString s.utf8ByteSize, s.toUpper, String.ofList s.toList.reverse,
   (s.drop 2).toString, (s.take 3).toString, toString (String.Pos.Raw.get s ⟨1⟩), toString (s.contains '🎉'),
   toString ("a,b,,c".splitOn ","), "  trim me ".trimAscii.toString, toString (decide ("x" < "y")), toString ("abc".startsWith "ab")]

def ints : List Int :=
  [(-7) / 2, (-7) % 2, 7 / (-2), 7 % (-2), Int.tdiv (-7) 2, Int.tmod (-7) 2, Int.fdiv (-7) 2,
   Int.fmod (-7) 2, (-7 : Int) / 0, (-7 : Int) % 0, Int.natAbs (-12), (-3 : Int) ^ 3]

def nats : List Nat :=
  [10 - 20, 10 / 0, 10 % 0, 2 ^ 100, Nat.gcd 84 36, Nat.lcm 4 6, 1000000007 * 1000000009,
   (2 ^ 70) / (2 ^ 3), (2 ^ 70) % 1000, Nat.log2 1025, 0xFF &&& 0x0F, 0xF0 ||| 0x0F, 5 ^^^ 3,
   1 <<< 65, (2 ^ 66) >>> 60]

def uints : List String :=
  [toString ((250 : UInt8) + 10), toString ((3 : UInt8) - 5), toString ((200 : UInt8) * 2),
   toString ((0 : UInt16) - 1), toString ((0 : UInt32) - 1), toString ((0 : UInt64) - 1),
   toString ((0xFFFFFFFFFFFFFFFF : UInt64) / 3), toString ((7 : UInt64) % 0),
   toString ((1 : UInt64) <<< 63), toString (((1 : UInt64) <<< 63) >>> 62),
   toString (decide ((0xFFFFFFFFFFFFFFFF : UInt64) < 1)), toString (UInt64.toNat 0xFFFFFFFFFFFFFFFF),
   toString ((300 : Nat).toUInt8), toString ((5 : UInt8).toUInt64 + 1), toString (~~~(0 : UInt32))]

def floats : List String :=
  [toString (1.5 + 2.25), toString (10.0 / 4.0), toString (Float.sqrt 2.0), toString (2.5 : Float).floor,
   toString (Float.ofNat 3), toString ((0.1 : Float) + 0.2 == 0.3), toString (1.0 / 0.0 : Float),
   toString (3.7 : Float).toUInt64, toString (Float.exp 1.0), toString (0.0 / 0.0 : Float),
   toString (-1.0 / 0.0 : Float), toString (1e300 * 1e10 : Float), toString (-0.0 : Float), toString (123456789.125 : Float),
   toString (-2.5 : Float).toUInt64, toString (1e30 : Float).toUInt64]

def chars : List String :=
  [toString 'a'.toNat, toString (Char.ofNat 955), toString 'Z'.toLower, toString '9'.isDigit,
   toString ('a'.toNat + 1 |> Char.ofNat)]

def lists : List String :=
  let xs := [5, 3, 8, 1, 9, 2]
  [toString xs.reverse, toString (xs.filter (· > 3)), toString (xs.zip xs.reverse),
   toString (xs.mergeSort (· ≤ ·)), toString (xs.foldr (· + ·) 0), toString xs.max?,
   toString (xs.take 2 ++ xs.drop 4), toString (xs.contains 8), toString (List.range 5),
   toString (xs.map (fun x => x * x) |>.sum), toString (xs.find? (· > 100)),
   toString ((xs.zip xs).lookup 8 |>.isNone), toString (List.replicate 3 'x')]

def arrays : List String :=
  let a := #[5, 3, 8, 1, 9, 2]
  [toString (a.qsort (· < ·)), toString (a.push 7).size, toString a[2]!, toString a[10]?,
   toString (a.set! 0 42), toString (a.map (· + 1)), toString (a.foldl (· + ·) 0),
   toString a.reverse, toString (a.filter (· % 2 == 0)), toString (a.extract 1 3),
   toString (a.swapIfInBounds 0 5), toString (Array.range 4), toString (a.contains 9),
   toString (Array.replicate 3 true)]

def options : List String :=
  let d : Option Nat := some 3
  [toString (d.map (· + 1)), toString (d.bind fun x => if x > 5 then some x else none),
   toString (d.getD 0), toString ((none : Option Nat).getD 9),
   toString (match (Except.error "bad" : Except String Nat) with | .ok v => s!"ok {v}" | .error e => s!"err {e}")]

def mixed : List String :=
  let m := mkMixed 7
  [reprStr m, reprStr (mkMixed 10), toString m.flag, toString m.small, toString m.word]

def shapes : List String :=
  [reprStr (Shape.rect 2 3), toString (area (.circle 4)), toString (area .dot),
   toString (Shape.rect 1 2 == Shape.rect 1 2), reprStr Color.blue.next, toString (Color.red == Color.green)]

def strings : List String :=
  [greet "λ", classify 0, classify 5, String.join ["a", "b", "c"], "x".pushn '!' 3,
   toString (String.intercalate ", " ["p", "q"]), toString "42".toNat?, toString "-17".toInt?,
   toString ("hello".replace "l" "L"), toString (hash "lean"), s!"{(12345 : Nat)}", toString "abc".length]

def recursion : List String :=
  [toString (sumAcc 0 200000), toString (parityEven 200001), toString (isEven 1000),
   toString (fact 30), toString (fib 90), toString (sumTo 2000)]

def float32s : List String :=
  let a : Float32 := 1.5
  let b : Float32 := 0.1
  [toString (a + b), toString (a * b), toString (a / b), toString (a - b), toString (decide (a < b)),
   toString (b.sqrt), toString a.toFloat, toString (Float32.ofNat 7), toString (a.toUInt64),
   toString (b == b), toString (Float.toFloat32 0.3)]

def byteArrays : List String :=
  let b := ByteArray.mk #[1, 2, 255]
  let c := (b.push 7).set! 0 9
  [toString b.size, toString c.toList, toString (c.get! 3), toString (b ++ c).toList,
   toString (b.extract 1 3).toList, toString "héllo".toUTF8.size, toString (String.fromUTF8! "abc".toUTF8),
   toString (ByteArray.empty.push 4).toList, toString (b.toList.foldl (· + ·.toNat) 0)]

def floatArrays : List String :=
  let f := FloatArray.mk #[1.5, 2.5]
  let g := (f.push 4.0).set! 0 0.5
  [toString f.size, toString g.toList, toString (g.get! 2), toString (g.toList.foldl (· + ·) 0)]

def thunks : List String :=
  let t : Thunk Nat := Thunk.mk fun _ => 6 * 7
  let p : Thunk String := Thunk.pure "ready"
  [toString t.get, toString p.get, toString (t.map (· + 1)).get, toString (t.bind fun n => Thunk.pure (n * 2)).get]

def tasks : List String :=
  let t := Task.spawn fun _ => (List.range 1000).foldl (· + ·) 0
  let p := Task.pure 5
  [toString t.get, toString p.get, toString (t.map (· + 1)).get, toString (p.bind fun n => Task.pure (n * 3)).get]

def traced : List String :=
  [toString (dbgTrace "lean-py dbgTrace" fun _ => 11)]

def report (_ : Unit) : String :=
  let sections : List (String × List String) := [
    ("basic", [toString (double 21), reprStr (Point.add ⟨1, -5⟩ ⟨2, 3⟩), toString (listMapSum [1, 2, 3]),
      toString (arrSquares 6), toString (firstEven? [1, 3, 4]), toString (u64wrap 0xFFFFFFFFFFFFFFFF 2)]),
    ("partials", partials.map toString),
    ("words", (wordFreq "the cat and the hat and the bat").map toString),
    ("unicode", unicode), ("ints", ints.map toString), ("nats", nats.map toString),
    ("uints", uints), ("floats", floats), ("chars", chars), ("lists", lists), ("arrays", arrays),
    ("options", options), ("mixed", mixed), ("shapes", shapes), ("strings", strings),
    ("recursion", recursion), ("float32s", float32s), ("byteArrays", byteArrays), ("floatArrays", floatArrays),
    ("thunks", thunks), ("tasks", tasks), ("traced", traced)]
  "\n".intercalate (sections.map fun (k, vs) => "\n".intercalate (vs.map (s!"{k}: " ++ ·)))

end LeanPythonTest.Vectors
