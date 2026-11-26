/* leanfran:lean fp
def fpSpec (a b c : Float) : Float := a * b + c
def widenSpec (x : UInt64) : UInt64 := x + 1
*/
#include "leanfran.h"

LF_MODEL("refines=fpSpec")
double muladd(double a, double b, double c) { return a * b + c; }

LF_MODEL("refines=widenSpec")
unsigned long widen(unsigned long x) { return x + 1; }
