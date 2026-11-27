import Shapes.Area
import Settings

namespace Report

structure Line where
  label : String
  origin : Shapes.Point
  size : Shapes.Area.Rect

def total (lines : List Line) : Nat := (lines.map fun l => Shapes.Area.area l.size).sum

def status (p : Shapes.Packet Shapes.Status) : Shapes.Status := p.payload

def boolean (p : Shapes.Packet Bool) : Bool := p.payload

def externalFlag (flag : Choice.Flag) : Choice.Flag := flag

def setting (s : Settings.Level) : Settings.Level := s

def grams (w : Loose.Weight) : UInt64 := w.grams

end Report
