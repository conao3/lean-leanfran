#include "shared_first.h"
#include "shared_second.h"

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    const bool fail = getenv("LEANFRAN_TEST_SHARED_INIT_ERROR") != NULL;
    const lf_status expected = fail ? LF_IO : LF_OK;
    lf_error error = {0};
    assert(shared_first_init(&error) == expected);
    lf_error_clear(&error);
    for (size_t i = 0; i < 2; i++) {
        assert(shared_second_init(&error) == expected);
        if (fail) {
            assert(strcmp(error.message, "shared initialization failed") == 0);
        }
        lf_error_clear(&error);
    }
    uint64_t first = 0;
    uint64_t second = 0;
    lf_status first_status = shared_first_first_counter(&first, NULL);
    lf_status second_status = shared_second_second_counter(&second, NULL);
    if (fail) {
        assert(first_status == LF_NOT_INITIALIZED);
        assert(second_status == LF_NOT_INITIALIZED);
    } else {
        assert(first_status == LF_OK && second_status == LF_OK);
        printf("%" PRIu64 " %" PRIu64 "\n", first, second);
    }
}
