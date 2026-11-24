#include "public_api.h"

int main(void) {
    uint32_t result;
    uint64_t count;
    return public_api_init(NULL) != LF_OK ||
           public_api_lookup(2, &result, NULL) != LF_OK || result != 29 ||
           public_api_counter(3, &count, NULL) != LF_OK || count != 33;
}
