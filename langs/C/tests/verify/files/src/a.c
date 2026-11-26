/* leanfran:lean dup
def aSpec (x : UInt32) : UInt32 := x + 1
def bSpec (x : UInt32) : UInt32 := x + 2
def twinA (x : UInt32) : UInt32 := x + 1
def twinB (x : UInt32) : UInt32 := x + 2 + 1
*/
#include "leanfran.h"

static uint32_t helper(uint32_t x) { return x + 1; }

LF_MODEL("refines=aSpec")
uint32_t fa(uint32_t x) { return helper(x); }

LF_MODEL("refines=twinA")
static uint32_t twin(uint32_t x) { return helper(x); }

uint32_t call_twin_a(uint32_t x) { return twin(x); }
