import Lean.Compiler.LCNF.Passes

namespace LeanPhpTest.ControlIr

open Lean.Compiler.LCNF

@[cpass] meta def keepRawReuse : PassInstaller :=
  PassInstaller.replacePass .impure `expandResetReuse fun _ =>
    { name := `expandResetReuse
      phase := .impure
      run := fun decls => do
        let expand : Array (Decl .impure) → CompilerM (Array (Decl .impure)) :=
          expandResetReuse.run
        let mut result := #[]
        for decl in decls do
          if decl.name == `LeanPhpTest.ControlIr.retagRaw then
            result := result.push decl
          else
            result := result ++ (← expand #[decl])
        return result }

inductive Label
  | empty
  | left (text : String) (count : Nat)
  | right (text : String) (count : Nat)

@[noinline] def retag : Label → Bool → Label
  | .left text count, keep =>
    if keep == (text.length == count) then .right (text.push '!') count else .empty
  | .right text count, _ => .left text (count + 1)
  | .empty, _ => .empty

@[noinline] def retagRaw : Label → Label
  | .left text count => .right (text.push '!') count
  | .right text count => .left text (count + 1)
  | .empty => .empty

@[noinline] def showLabel : Label → String
  | .empty => "empty"
  | .left s n => s!"left {s} {n}"
  | .right s n => s!"right {s} {n}"

structure Packed where
  name : String
  size : USize
  flag : UInt8
  double : Float
  wide : UInt64
  single : Float32

@[noinline] def pack (name : String) (size : USize) (flag : UInt8) (double : Float)
    (wide : UInt64) (single : Float32) : Packed :=
  ⟨name, size, flag, double, wide, single⟩

@[noinline] def packLine (p : Packed) : String :=
  s!"packed {p.name} {p.size.toNat} {p.flag.toNat} {p.double} {p.wide.toNat} {p.single.toBits.toNat}"

@[noinline] def applyPacked (f : UInt64 → Float32 → String) (wide : UInt64) (single : Float32) : String :=
  f wide single

@[noinline] def capturePacked (wide : UInt64) (single : Float32) (b : Bool) : UInt64 → Float32 → String :=
  if b then fun a f => s!"{(wide + a).toNat} {(single + f).toBits.toNat}"
  else fun a f => s!"{(wide - a).toNat} {(single - f).toBits.toNat}"

@[noinline] def joinLine (swap : Bool) (a b : Nat) : String :=
  let finish := fun x y => s!"join {x} {y}"
  if swap then finish b a else finish a b

@[noinline] def impossible (x : Empty) : Nat := nomatch x

@[noinline] def panicValue (message : String) : Nat := panic! message

def retagLine (old : Label) : String :=
  let shared := retag old true
  let rawShared := retagRaw old
  s!"reuse {showLabel shared} | {showLabel rawShared} | {showLabel old}"

def run (name : String) : IO Unit := do
  IO.println (retagLine (.left name 5))
  IO.println (showLabel (retag (.left (name.push '?') 8) false))
  IO.println (showLabel (retag (.left (name.push '?') 8) true))
  IO.println (showLabel (retagRaw (.left (name.push '?') 8)))
  IO.println (packLine (pack name 0xffffffffffffffff 255 2.5 0xffffffffffffffff 1.25))
  let f := capturePacked 0xffffffffffffffff 1.25 true
  IO.println (applyPacked f 3 0.5)
  IO.println (joinLine true 12 45)
  IO.println (joinLine false 12 45)
  IO.println s!"panic default {panicValue name}"

end LeanPhpTest.ControlIr
