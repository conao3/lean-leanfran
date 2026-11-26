/* leanfran:lean lim
def limSpec (x : Int32) : Bool := x < 10
*/
#include "leanfran.h"

enum { LIMIT = 10 };

LF_MODEL("refines=limSpec")
bool below(int32_t x) { return x < LIMIT; }
