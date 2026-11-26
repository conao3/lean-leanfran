/* leanfran:lean clamp
def spec (lo hi x : Int32) : Int32 := if x < lo then lo else if x > hi then hi
else x def ordered (lo hi _x : Int32) : Bool := lo ≤ hi
*/
#include "leanfran.h"

LF_MODEL("refines=spec", "requires=ordered")
int32_t clamp(int32_t lo, int32_t hi, int32_t x) {
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}
