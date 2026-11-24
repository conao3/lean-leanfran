namespace LeanGoTest.ControlRace

initialize heading : String ← pure "先"

@[noinline] def shared : Array String := #[heading, "猫"]

@[noinline] def appendName (label name : String) : String := label ++ name

@[noinline] def capture (label : String) : String → String := appendName label

@[noinline] def formatter : String → String := capture (heading.push ':')

@[noinline] def useClosure (f : String → String) (name : String) : String := f name

@[noinline] def render (name : String) : String :=
  let withName := shared.push name
  useClosure formatter (withName[1]! ++ withName[2]!)

end LeanGoTest.ControlRace
