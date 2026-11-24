#include "public_api.h"

#include <assert.h>
#include <lean/mimalloc.h>
#include <stdio.h>
#include <string.h>

static bool count_area(const mi_heap_t *heap, const mi_heap_area_t *area,
                       void *block, size_t block_size, void *data) {
    (void)heap;
    (void)block;
    (void)block_size;
    *(size_t *)data += area->used;
    return true;
}

static size_t live_blocks(void) {
    size_t count = 0;
    mi_heap_visit_blocks(mi_heap_main(), false, count_area, &count);
    return count;
}

static void call_string_functions(void) {
    lf_str out;
    assert(public_api_greeting((lf_str){"C", 1}, &out, NULL) == LF_OK);
    assert(out.len > 1);
    lf_free(out.ptr);
    assert(public_api_repeat_string((lf_str){"abc", 3}, &out, NULL) == LF_OK);
    assert(out.len == 6 && memcmp(out.ptr, "abcabc", 6) == 0);
    lf_free(out.ptr);
    assert(public_api_effect(true, NULL) == LF_IO);
}

static int check_live_blocks(size_t before) {
    size_t after = live_blocks();
    if (before != after) {
        fprintf(stderr, "mimalloc live blocks changed from %zu to %zu\n",
                before, after);
        return 1;
    }
    return 0;
}

int main(void) {
    assert(public_api_init(NULL) == LF_OK);
    call_string_functions();
    size_t before = live_blocks();
    for (size_t i = 0; i < 10000; i++) {
        call_string_functions();
    }
    if (check_live_blocks(before)) {
        return 1;
    }
    assert(public_api_retain_for_refcount((lf_str){"retained", 8}, NULL) ==
           LF_OK);
    lf_str out;
    before = live_blocks();
    assert(public_api_retained_for_refcount(&out, NULL) == LF_OK);
    assert(out.len == 8);
    lf_free(out.ptr);
    return check_live_blocks(before);
}
