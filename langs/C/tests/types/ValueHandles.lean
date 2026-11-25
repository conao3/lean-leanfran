namespace Handles

structure Line where
  description : String
  quantity : UInt64
  price : UInt64

def total (lines : Array Line) : UInt64 :=
  lines.foldl (fun acc line => acc + line.quantity * line.price) 0

def push (lines : Array Line) (line : Line) : Array Line :=
  lines.push line

def firstPrice (lines : Array Line) : UInt64 :=
  match lines[0]? with
  | some line => line.price
  | none => 0

def checked (value : Int64) (accept : Bool) : IO (Except String Int64) :=
  if !accept then pure (.error "rejected")
  else if value == 0 then throw (IO.userError "zero")
  else pure (.ok value)

end Handles
