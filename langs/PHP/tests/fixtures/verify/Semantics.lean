import LeanPhpLib.Php

namespace Semantics

def intMin (a b : Int) : Int := min a b
def intMax (a b : Int) : Int := max a b

def intCompare (a b : Int) : UInt8 :=
  (if a == b then 1 else 0) + (if a < b then 2 else 0) + (if a ≤ b then 4 else 0) +
    (if a > b then 8 else 0) + (if a ≥ b then 16 else 0)

def floatCompare (a b : Float) : UInt8 :=
  (if a == b then 1 else 0) + (if a < b then 2 else 0) + (if a ≤ b then 4 else 0) +
    (if a > b then 8 else 0) + (if a ≥ b then 16 else 0)

def boolCompare (a b : Bool) : UInt8 :=
  (if a == b then 1 else 0) + (if a < b then 2 else 0) + (if a ≤ b then 4 else 0) +
    (if a > b then 8 else 0) + (if a ≥ b then 16 else 0)

def stringEqual (a b : String) : Bool := a == b
def index (a : List Int) (i : Int) : Php.M Int := Php.getItem a i
def count (a : List Int) : Int := Php.count a
def matchOne (n : Int) : Php.M Int := if n == 1 then .ok 5 else .error .unhandledMatch
def floatAdd (a b : Float) : Float := a + b
def floatSub (a b : Float) : Float := a - b
def floatMul (a b : Float) : Float := a * b
def floatNeg (a : Float) : Float := -a
def floatAbs (a : Float) : Float := Float.abs a
def natOption (a : Option Int) : Bool := Php.isNull a

end Semantics
