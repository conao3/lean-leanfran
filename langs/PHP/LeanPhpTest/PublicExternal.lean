import LeanPhpTest.Public

namespace LeanPhpTest.PublicExternal

open LeanPhpTest.Public

def echoRange (r : Range) : Range := r

def echoDiscount (d : Discount) : Discount := d

structure Frame extends Range where
  tag : String

def echoFrame (f : Frame) : Frame := f

end LeanPhpTest.PublicExternal
