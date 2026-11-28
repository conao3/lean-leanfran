#include "flags.h"
#include <stdio.h>

int main(void) {
    lf_error err = {0};
    flags_choice_flag flag = {.enabled = true};
    bool enabled = false;
    if (flags_init(&err) != LF_OK ||
        flags_enabled(&flag, &enabled, &err) != LF_OK) {
        fprintf(stderr, "flags: %s\n", err.message);
        return 1;
    }
    printf("flags enabled=%d\n", enabled);
    return 0;
}
