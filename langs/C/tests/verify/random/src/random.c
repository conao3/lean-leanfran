/* leanfran:lean random
def clampSpec (lo hi x : Int32) : Int32 :=
  if x < lo then lo else if x > hi then hi else x
def ordered (lo hi _x : Int32) : Bool := lo ≤ hi
def atMost (x : Int32) : Bool := x ≤ 10
def addSpec (a b : Int32) : Int32 := a + b
def small (a b : Int32) : Bool :=
  -1000 < a && a < 1000 && -1000 < b && b < 1000
def total (xs : Array UInt64) : UInt64 := xs.foldl (· + ·) 0
def covers (xs : Array UInt64) (r : UInt64) : Bool := xs.size > 0 || r == 0
def mid (a b : Float) : Float := (a + b) / 2
def negate (b : Bool) : Bool := !b
*/
#include "leanfran.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

LF_MODEL("refines=clampSpec", "requires=ordered")
int32_t clamp(int32_t lo, int32_t hi, int32_t x) {
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}

LF_MODEL("refines=atMost")
bool at_most(int32_t x) { return x <= 10; }

LF_MODEL("refines=addSpec", "requires=small")
int32_t add(int32_t a, int32_t b) { return a + b; }

LF_MODEL("refines=total", "ensures=empty:covers")
uint64_t sum(const uint64_t *xs LF_ARRAY(n), size_t n) {
    uint64_t s = 0;
    for (size_t i = 0; i < n; i++)
        s += xs[i];
    return s;
}

LF_MODEL("refines=mid")
double midpoint(double a, double b) { return (a + b) / 2; }

LF_MODEL("refines=negate")
static bool hidden(bool b) { return !b; }

bool use_hidden(bool b) { return hidden(b); }
