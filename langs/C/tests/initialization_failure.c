#include "broken.h"

#include <assert.h>
#include <string.h>

int main(void) {
    for (size_t i = 0; i < 2; i++) {
        lf_error error = {0};
        assert(broken_init(&error) == LF_IO);
        assert(error.status == LF_IO);
        assert(strcmp(error.message, "initialization failed") == 0);
        lf_error_clear(&error);
    }
    uint8_t value;
    assert(broken_sample(&value, NULL) == LF_NOT_INITIALIZED);
}
