#include "public_types.h"
#include <assert.h>
#include <lean/mimalloc.h>
#include <stdio.h>
#include <string.h>

static bool count_blocks(const mi_heap_t *heap, const mi_heap_area_t *area,
                         void *block, size_t block_size, void *arg) {
    (void)heap;
    (void)block;
    (void)block_size;
    *(size_t *)arg += area->used;
    return true;
}

static size_t live_blocks(void) {
    size_t count = 0;
    mi_heap_visit_blocks(mi_heap_main(), false, count_blocks, &count);
    return count;
}

static void check_codec(lf_error *err) {
    public_types_schema_record value, decoded;
    assert(public_types_sample(&value, err) == LF_OK);
    lf_str json, again;
    assert(public_types_schema_record_to_json(&value, &json, err) == LF_OK);
    lf_status status =
        public_types_schema_record_from_json(json.ptr, json.len, &decoded, err);
    if (status != LF_OK)
        fprintf(stderr, "Could not decode %s: %s\n", json.ptr, err->message);
    assert(status == LF_OK);
    assert(public_types_schema_record_to_json(&decoded, &again, err) == LF_OK);
    assert(json.len == again.len && memcmp(json.ptr, again.ptr, json.len) == 0);
    assert(fwrite(json.ptr, 1, json.len, stdout) == json.len);
    assert(putchar('\n') != EOF);

    const char invalid_utf8[] = {'"', (char)0xFF, '"'};
    assert(public_types_schema_record_from_json(invalid_utf8,
                                                sizeof(invalid_utf8), &decoded,
                                                err) == LF_INVALID);
    const char invalid_type[] = "{\"huge\":false}";
    assert(public_types_schema_record_from_json(invalid_type,
                                                strlen(invalid_type), &decoded,
                                                err) == LF_INVALID);
    lf_free(again.ptr);
    lf_free(json.ptr);
    public_types_schema_record_free(&decoded);
    public_types_schema_record_free(&value);
}

static void check_invariants(lf_error *err) {
    public_types_checked_range value = {
        .low = lf_nat_from_u64(2),
        .high = lf_nat_from_u64(7),
        .limit = lf_nat_from_u64(4),
        .capacity = 12,
    };
    public_types_checked_range output;
    assert(public_types_checked_range_valid(&value, err));
    assert(public_types_echo(&value, &output, err) == LF_OK);
    public_types_checked_range_free(&output);

    value.capacity = 20;
    assert(!public_types_checked_range_valid(&value, err));
    assert(strcmp(err->message, "Invalid Checked.Small.property") == 0);
    value.capacity = 12;
    value.limit = lf_nat_from_u64(8);
    assert(public_types_echo(&value, &output, err) == LF_INVALID);
    assert(strcmp(err->message, "Invalid Fin.isLt") == 0);
    value.limit = lf_nat_from_u64(4);
    value.low = lf_nat_from_u64(8);
    lf_str json;
    assert(public_types_checked_range_to_json(&value, &json, err) ==
           LF_INVALID);
    assert(strcmp(err->message, "Invalid Checked.Range.ordered") == 0);
    value.low = lf_nat_from_u64(0);
    value.high = lf_nat_from_u64(0);
    assert(!public_types_checked_range_valid(&value, err));
    assert(strcmp(err->message, "Invalid Checked.Range.nonzero") == 0);

    const char valid_json[] =
        "{\"low\":0,\"high\":5,\"limit\":7,\"capacity\":19}";
    assert(public_types_checked_range_from_json(valid_json, strlen(valid_json),
                                                &output, err) == LF_OK);
    assert(output.limit.value == 7 && output.capacity == 19);
    public_types_checked_range_free(&output);
    const char invalid_json[] =
        "{\"low\":1,\"high\":0,\"limit\":7,\"capacity\":19}";
    assert(public_types_checked_range_from_json(
               invalid_json, strlen(invalid_json), &output, err) == LF_INVALID);
    assert(strcmp(err->message, "Invalid Checked.Range.ordered") == 0);
    lf_error_clear(err);

    public_types_array_checked_range batch = {.items = &value, .len = 1},
                                     batch_out;
    assert(public_types_batch(&batch, &batch_out, NULL) == LF_INVALID);
    const size_t before = live_blocks();
    for (size_t i = 0; i < 1000; ++i) {
        assert(public_types_batch(&batch, &batch_out, NULL) == LF_INVALID);
        assert(public_types_checked_range_from_json(
                   invalid_json, strlen(invalid_json), &output, NULL) ==
               LF_INVALID);
    }
    assert(live_blocks() == before);
}

int main(void) {
    lf_error error = {0};
    assert(!public_types_checked_range_valid(NULL, &error));
    assert(error.status == LF_NOT_INITIALIZED);
    assert(public_types_init(&error) == LF_OK);
    check_codec(&error);
    check_invariants(&error);
    lf_error_clear(&error);
    return 0;
}
