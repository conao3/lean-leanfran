namespace Php

inductive Exc where
  | overflow
  | divisionByZero
  | arithmeticError
  | undefinedIndex
  | unhandledMatch
  | thrown (className : String)
  deriving DecidableEq, Repr

abbrev M := Except Exc

def checked (n : Int) : M Int :=
  if -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807 then .ok n
  else .error .overflow

def add (a b : Int) : M Int := checked (a + b)
def sub (a b : Int) : M Int := checked (a - b)
def mul (a b : Int) : M Int := checked (a * b)
def neg (a : Int) : M Int := checked (-a)
def abs (a : Int) : M Int := if a < 0 then neg a else .ok a

def intdiv (a b : Int) : M Int :=
  if b = 0 then .error .divisionByZero
  else if a = -9223372036854775808 ∧ b = -1 then .error .arithmeticError
  else .ok (a.tdiv b)

def mod (a b : Int) : M Int :=
  if b = 0 then .error .divisionByZero else .ok (a.tmod b)

def fdiv (a b : Float) : M Float :=
  if b == 0 then .error .divisionByZero else .ok (a / b)

def getItem (xs : List α) (i : Int) : M α :=
  if i < 0 then .error .undefinedIndex
  else match xs[i.toNat]? with
    | some item => .ok item
    | none => .error .undefinedIndex

def count (xs : List α) : Int := xs.length
def strlen (s : String) : Int := s.utf8ByteSize
def concat (a b : String) : String := a ++ b

def isNull (v : Option α) : Bool := v.isNone

def minFloat (a b : Float) : Float := if a < b then a else b
def maxFloat (a b : Float) : Float := if b ≤ a then a else b

end Php
