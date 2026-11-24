#include "public_api.h"

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    lf_error error = {0};
    uint64_t u64 = 0;
    assert(public_api_counter(1, &u64, &error) == LF_NOT_INITIALIZED);
    assert(u64 == 0);
    assert(error.status == LF_NOT_INITIALIZED && error.message != NULL);
    lf_error_clear(&error);
    assert(public_api_init(&error) == LF_OK);
    assert(public_api_init(NULL) == LF_OK);
    assert(public_api_counter(strtoull(argv[1], NULL, 10), &u64, &error) ==
           LF_OK);
    printf("%" PRIu64 "\n", u64);
    assert(public_api_scalars(true, UINT8_MAX, UINT16_MAX, UINT32_MAX, 123,
                              &u64, NULL) == LF_OK);
    printf("%" PRIu64 "\n", u64);

    int8_t i8;
    assert(public_api_int8(INT8_MIN, &i8, NULL) == LF_OK);
    printf("%" PRId8 "\n", i8);
    int16_t i16;
    assert(public_api_int16(INT16_MIN, &i16, NULL) == LF_OK);
    printf("%" PRId16 "\n", i16);
    int32_t i32;
    assert(public_api_int32(INT32_MIN, &i32, NULL) == LF_OK);
    printf("%" PRId32 "\n", i32);
    int64_t i64;
    assert(public_api_int64(INT64_MIN, &i64, NULL) == LF_OK);
    printf("%" PRId64 "\n", i64);

    double d;
    assert(public_api_double_value(1.25, &d, NULL) == LF_OK && d == 2.5);
    printf("%u\n", (unsigned)d);
    float f;
    assert(public_api_float_value(1.5f, &f, NULL) == LF_OK);
    printf("%u\n", (unsigned)f);
    uint32_t u32;
    assert(public_api_character(0x1f642, &u32, NULL) == LF_OK);
    printf("%" PRIu32 "\n", u32);
    assert(public_api_character(0xd800, &u32, NULL) == LF_INVALID);
    assert(public_api_character('a', NULL, NULL) == LF_INVALID);

    lf_str string;
    assert(public_api_greeting((lf_str){"世界", strlen("世界")}, &string,
                               NULL) == LF_OK);
    printf("%.*s\n", (int)string.len, string.ptr);
    lf_free(string.ptr);
    assert(public_api_repeat_string((lf_str){"a\0b", 3}, &string, NULL) ==
           LF_OK);
    printf("[");
    for (size_t i = 0; i < string.len; i++) {
        printf("%s%u", i == 0 ? "" : ", ", (unsigned)(uint8_t)string.ptr[i]);
    }
    printf("]\n");
    lf_free(string.ptr);
    assert(public_api_repeat_string((lf_str){NULL, 1}, &string, NULL) ==
           LF_INVALID);
    assert(public_api_empty_string(&string, NULL) == LF_OK);
    printf("%zu\n", string.len);
    lf_free(string.ptr);

    assert(public_api_lookup(2, &u32, NULL) == LF_OK);
    printf("%" PRIu32 "\n", u32);
    const bool fail = argc > 2 && strcmp(argv[2], "fail") == 0;
    lf_status status = public_api_effect(fail, &error);
    if (status == LF_IO) {
        fprintf(stderr, "%s\n", error.message);
        lf_error_clear(&error);
        return 7;
    }
    assert(status == LF_OK);
    return 0;
}
