import Aeneas
import LeanRustGen.Model.leanfran_verify_test.Types
namespace counters

open Aeneas Aeneas.Std leanfran_verify_test

def reset (c : counter.Counter) : counter.Counter := { c with count := 0#u32 }

end counters
