#include "checks.h"

uint32_t leanfran_test_increment(uint32_t n) { return n + 2; }

int main(void) {
    uint32_t result;
    return checks_init(NULL) != LF_OK ||
           checks_with_extern(3, &result, NULL) != LF_OK || result != 5;
}
