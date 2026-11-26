#include "leanfran.h"

static uint32_t helper(uint32_t x) { return x + 2; }

LF_MODEL("refines=bSpec", "spec=dup")
uint32_t fb(uint32_t x) { return helper(x); }

LF_MODEL("refines=twinB", "spec=dup")
static uint32_t twin(uint32_t x) { return helper(x) + 1; }

uint32_t call_twin_b(uint32_t x) { return twin(x); }
