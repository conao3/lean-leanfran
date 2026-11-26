#include "pricing.h"
#include <inttypes.h>
#include <stdio.h>

int main(void) {
    lf_error error = {0};
    uint64_t total;
    if (pricing_init(&error) != LF_OK ||
        pricing_total(3, 1200, &total, &error) != LF_OK) {
        fprintf(stderr, "%s\n",
                error.message ? error.message : "Lean call failed");
        lf_error_clear(&error);
        return 1;
    }
    printf("%" PRIu64 "\n", total);
    return 0;
}
