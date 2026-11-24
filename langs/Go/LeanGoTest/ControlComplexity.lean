namespace LeanGoTest.ControlComplexity

def arrayPush (n : Nat) (a : Array Nat) : Array Nat :=
  if n = 0 then a else arrayPush (n - 1) (a.push n)

def arraySet (n : Nat) (a : Array Nat) : Array Nat :=
  if n = 0 then a else arraySet (n - 1) (a.set! (n - 1) n)

def stringPush (n : Nat) (s : String) : String :=
  if n = 0 then s else stringPush (n - 1) (s.push '猫')

def stringAppend (n : Nat) (s suffix : String) : String :=
  if n = 0 then s else stringAppend (n - 1) (s ++ suffix) suffix

def bytePush (n : Nat) (a : ByteArray) : ByteArray :=
  if n = 0 then a else bytePush (n - 1) (a.push 255)

def byteSet (n : Nat) (a : ByteArray) : ByteArray :=
  if n = 0 then a else byteSet (n - 1) (a.set! (n - 1) 255)

end LeanGoTest.ControlComplexity
