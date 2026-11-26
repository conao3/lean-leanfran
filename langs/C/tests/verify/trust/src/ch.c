/* leanfran:lean ch
def wrongSpec (x : UInt32) : UInt32 := x + 2
*/
#include "leanfran.h"

LF_MODEL("refines=wrongSpec")
uint32_t inc(uint32_t x) { return x + 1; }
