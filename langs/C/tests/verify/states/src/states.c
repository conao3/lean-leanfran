/* leanfran:lean states
def incSpec (n : UInt32) : UInt32 := n + 1
def bigger (n r : UInt32) : Bool := r == n + 1
def clampSpec (lo hi x : Int32) : Int32 := if x < lo then lo else if x > hi then
hi else x def ordered (lo hi _x : Int32) : Bool := lo ≤ hi
*/
#include "leanfran.h"

static int counter;

LF_MODEL("refines=incSpec", "ensures=changes:bigger")
uint32_t proved(uint32_t n) { return n + 1; }

LF_MODEL("refines=clampSpec", "requires=ordered")
int32_t clamp(int32_t lo, int32_t hi, int32_t x) {
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}

LF_MODEL("refines=incSpec")
uint32_t sorry_case(uint32_t n) { return n + 1; }

LF_MODEL("refines=incSpec")
uint32_t axioms_case(uint32_t n) { return n + 1; }

LF_MODEL("refines=incSpec")
uint32_t missing_case(uint32_t n) { return n + 1; }

LF_MODEL("refines=incSpec")
uint32_t mismatch_case(uint32_t n) { return n + 1; }

LF_MODEL("refines=incSpec")
uint32_t failed_case(uint32_t n) { return n + 1; }

LF_MODEL("refines=incSpec")
uint32_t unsupported(uint32_t n) { return n + (uint32_t)counter; }
