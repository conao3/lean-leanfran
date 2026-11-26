/* leanfran:lean inst
instance : HAdd UInt32 UInt32 UInt32 := ⟨fun a _ => a⟩
def keep (x : UInt32) : UInt32 := x
*/
#include "leanfran.h"

LF_MODEL("refines=keep")
uint32_t bump(uint32_t x) { return x + 1; }
