/* leanfran:lean div
import LeanCLib.C

def divSpec (a b : Int32) : C.Status × Option Int32 :=
  if b = 0 then (C.Status.invalid, none) else (C.Status.ok, some (a / b))
def safe (a b : Int32) : Bool := !(a == -2147483648 && b == -1)
*/
#include "leanfran.h"

LF_MODEL("refines=divSpec", "requires=safe")
lf_status safe_div(int32_t a, int32_t b, int32_t *out) {
    if (b == 0)
        return LF_INVALID;
    *out = a / b;
    return LF_OK;
}
