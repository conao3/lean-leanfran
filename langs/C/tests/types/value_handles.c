#define _POSIX_C_SOURCE 200809L

#include "value_handles.h"

#include <assert.h>
#include <inttypes.h>
#include <lean/lean.h>
#include <lean/mimalloc.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum { initial_size = 10000, pushes = 10000, thread_count = 8, reads = 100000 };

static const value_handles_handles_line sample = {{"Line item", 9}, 3, 5};

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

static void *read_shared(void *arg) {
    lf_thread_attach();
    lf_thread_attach();
    const value_handles_array_handles_line_ref lines =
        *(const value_handles_array_handles_line_ref *)arg;
    for (size_t i = 0; i < reads; ++i) {
        value_handles_type_uint64_ref result = {0};
        uint64_t price;
        assert(value_handles_first_price_ref(lines, &result, NULL) == LF_OK);
        assert(value_handles_type_uint64_ref_get(result, &price, NULL) ==
               LF_OK);
        assert(price == sample.price);
        value_handles_type_uint64_ref_release(result);
    }
    lf_thread_detach();
    lf_thread_detach();
    return NULL;
}

static void check_handles(void) {
    value_handles_handles_line *items = calloc(initial_size, sizeof(*items));
    assert(items != NULL);
    for (size_t i = 0; i < initial_size; ++i) {
        items[i] = sample;
    }
    value_handles_array_handles_line input = {items, initial_size};
    value_handles_array_handles_line_ref lines;
    assert(value_handles_array_handles_line_ref_from(&input, &lines, NULL) ==
           LF_OK);
    free(items);

    value_handles_handles_line_ref line;
    assert(value_handles_handles_line_ref_from(&sample, &line, NULL) == LF_OK);
    value_handles_array_handles_line_ref copy;
    assert(value_handles_push_ref(lines, line, &copy, NULL) == LF_OK);
    assert(copy.obj != lines.obj);
    assert(lean_array_size(lines.obj) == initial_size);
    assert(lean_array_size(copy.obj) == initial_size + 1);
    value_handles_array_handles_line_ref_release(copy);

    size_t reused = 0;
    for (size_t i = 0; i < pushes; ++i) {
        assert(lean_is_exclusive(lines.obj));
        bool spare =
            lean_array_size(lines.obj) < lean_array_capacity(lines.obj);
        uintptr_t address = (uintptr_t)lines.obj;
        assert(value_handles_push_ref_take(
                   lines, value_handles_handles_line_ref_retain(line), &lines,
                   NULL) == LF_OK);
        if (spare) {
            assert((uintptr_t)lines.obj == address);
            ++reused;
        }
        assert(lean_array_size(lines.obj) == initial_size + i + 1);
    }
    assert(reused >= pushes - 2);
    value_handles_handles_line_ref_release(line);

    value_handles_array_handles_line output;
    assert(value_handles_array_handles_line_ref_get(lines, &output, NULL) ==
           LF_OK);
    assert(output.len == initial_size + pushes);
    assert(output.items[output.len - 1].price == sample.price);
    assert(output.items[0].description.len == sample.description.len);
    assert(memcmp(output.items[0].description.ptr, sample.description.ptr,
                  sample.description.len) == 0);
    value_handles_array_handles_line_free(&output);

    value_handles_array_handles_line_ref_share(lines);
    assert(lean_is_mt(lines.obj));
    lean_object *row = lean_array_get_core(lines.obj, 0);
    assert(lean_is_mt(row));
    assert(lean_is_mt(lean_ctor_get(row, 0)));
    int original_count = lean_internal_get_rc(lines.obj);
    pthread_t threads[thread_count];
    for (size_t i = 0; i < thread_count; ++i) {
        assert(pthread_create(&threads[i], NULL, read_shared, &lines) == 0);
    }
    for (size_t i = 0; i < thread_count; ++i) {
        assert(pthread_join(threads[i], NULL) == 0);
    }
    assert(lean_internal_get_rc(lines.obj) == original_count);
    value_handles_array_handles_line_ref_release(lines);
}

static void check_errors(void) {
    const int64_t input = INT64_MIN;
    const bool yes = true, no = false;
    value_handles_type_int64_ref value, out = {0};
    value_handles_type_bool_ref accept, reject;
    assert(value_handles_type_int64_ref_from(&input, &value, NULL) == LF_OK);
    assert(value_handles_type_bool_ref_from(&yes, &accept, NULL) == LF_OK);
    assert(value_handles_type_bool_ref_from(&no, &reject, NULL) == LF_OK);

    assert(value_handles_checked_ref_take(value, accept, NULL, NULL) ==
           LF_INVALID);
    assert(value_handles_checked_ref_take(value,
                                          (value_handles_type_bool_ref){0},
                                          &out, NULL) == LF_INVALID);
    assert(out.obj == NULL);
    int64_t result;
    assert(value_handles_type_int64_ref_get(value, &result, NULL) == LF_OK);
    assert(result == input);

    assert(value_handles_checked_ref(value, accept, &out, NULL) == LF_OK);
    assert(value_handles_type_int64_ref_get(out, &result, NULL) == LF_OK);
    assert(result == input);
    value_handles_type_int64_ref_release(out);
    out = (value_handles_type_int64_ref){0};
    lf_error error = {0};
    assert(value_handles_checked_ref_take(value, reject, &out, &error) ==
           LF_EXCEPT);
    assert(out.obj == NULL && strcmp(error.message, "\"rejected\"") == 0);
    const int64_t zero = 0;
    assert(value_handles_type_int64_ref_from(&zero, &value, NULL) == LF_OK);
    assert(value_handles_checked_ref_take(value, accept, &out, &error) ==
           LF_IO);
    assert(out.obj == NULL && strstr(error.message, "zero") != NULL);
    lf_error_clear(&error);
}

static uint64_t nanos(void) {
    struct timespec time;
    assert(clock_gettime(CLOCK_MONOTONIC, &time) == 0);
    return (uint64_t)time.tv_sec * 1000000000 + (uint64_t)time.tv_nsec;
}

static void benchmark(void) {
    enum { rows = 100, calls = 100000 };
    value_handles_handles_line items[rows];
    for (size_t i = 0; i < rows; ++i) {
        items[i] = sample;
    }
    value_handles_array_handles_line input = {items, rows};
    value_handles_array_handles_line_ref lines;
    assert(value_handles_array_handles_line_ref_from(&input, &lines, NULL) ==
           LF_OK);

    uint64_t begin = nanos();
    for (size_t i = 0; i < calls; ++i) {
        uint64_t result;
        assert(value_handles_total(&input, &result, NULL) == LF_OK);
        assert(result == rows * sample.quantity * sample.price);
    }
    uint64_t public_elapsed = nanos() - begin;
    begin = nanos();
    for (size_t i = 0; i < calls; ++i) {
        value_handles_type_uint64_ref handle;
        uint64_t result;
        assert(value_handles_total_ref(lines, &handle, NULL) == LF_OK);
        assert(value_handles_type_uint64_ref_get(handle, &result, NULL) ==
               LF_OK);
        assert(result == rows * sample.quantity * sample.price);
        value_handles_type_uint64_ref_release(handle);
    }
    uint64_t ref_elapsed = nanos() - begin;
    value_handles_array_handles_line_ref_release(lines);
    printf("public %.3f us/call, value handle %.3f us/call (%d calls each)\n",
           (double)public_elapsed / calls / 1000,
           (double)ref_elapsed / calls / 1000, calls);
}

int main(int argc, char **argv) {
    const uint64_t number = 1;
    value_handles_type_uint64_ref before_init = {0};
    assert(value_handles_type_uint64_ref_from(&number, &before_init, NULL) ==
           LF_NOT_INITIALIZED);
    assert(value_handles_init(NULL) == LF_OK);
    if (argc == 2 && strcmp(argv[1], "--benchmark") == 0) {
        benchmark();
    } else {
        check_errors();
        check_handles();
        mi_collect(true);
        size_t before = live_blocks();
        check_errors();
        check_handles();
        mi_collect(true);
        assert(live_blocks() == before);
    }
    lf_thread_detach();
    return 0;
}
