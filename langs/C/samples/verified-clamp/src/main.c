#include "clamp.h"
#include <inttypes.h>
#include <stdio.h>

int32_t clamp(int32_t lo, int32_t hi, int32_t x);

int main(void) {
    lf_error error = {0};
    if (clamp_init(&error) != LF_OK) {
        fprintf(stderr, "%s\n", error.message);
        lf_error_clear(&error);
        return 1;
    }
    const int32_t inputs[] = {-5, 0, 7, 10, 12};
    for (size_t i = 0; i < sizeof inputs / sizeof inputs[0]; i++) {
        int32_t expected;
        if (clamp_spec(0, 10, inputs[i], &expected, &error) != LF_OK) {
            fprintf(stderr, "%s\n", error.message);
            lf_error_clear(&error);
            return 1;
        }
        printf("clamp(0, 10, %" PRId32 ") = %" PRId32 ", spec %" PRId32 "\n",
               inputs[i], clamp(0, 10, inputs[i]), expected);
    }
    return 0;
}
