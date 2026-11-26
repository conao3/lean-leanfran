#include "public_types.h"
#include <assert.h>
#include <lean/mimalloc.h>
#include <math.h>
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

static void check_naturals(lf_error *err) {
    const char *cases[] = {"0", "9223372036854775808", "18446744073709551615",
                           "18446744073709551616",
                           "123456789012345678901234567890"};
    const uint64_t small[] = {0, UINT64_C(9223372036854775808), UINT64_MAX};
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        lf_nat in, out;
        lf_str decimal;
        assert(lf_nat_from_dec(cases[i], &in, err) == LF_OK);
        assert(public_types_naturals(&in, &out, err) == LF_OK);
        uint64_t n = 17;
        if (i < sizeof(small) / sizeof(*small)) {
            assert(lf_nat_to_u64(&out, &n) && n == small[i]);
        } else {
            assert(!lf_nat_to_u64(&out, &n) && n == 17);
        }
        assert(lf_nat_to_dec(&out, &decimal, err) == LF_OK);
        assert(strcmp(decimal.ptr, cases[i]) == 0);
        lf_free(decimal.ptr);
        lf_nat_free(&in);
        lf_nat_free(&out);
    }
    lf_nat out;
    assert(lf_nat_from_dec("-1", &out, err) == LF_INVALID);
    assert(lf_nat_from_dec("18446744073709551616x", &out, err) == LF_INVALID);
    assert(lf_nat_from_dec("00018446744073709551616", &out, err) == LF_OK);
    assert(strcmp(out.decimal, "18446744073709551616") == 0);
    lf_nat_free(&out);
}

static void check_integers(lf_error *err) {
    const char *cases[] = {"-9223372036854775808", "9223372036854775807",
                           "-9223372036854775809", "9223372036854775808",
                           "-123456789012345678901234567890"};
    const int64_t small[] = {INT64_MIN, INT64_MAX};
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) {
        lf_int in, out;
        lf_str decimal;
        assert(lf_int_from_dec(cases[i], &in, err) == LF_OK);
        assert(public_types_integers(&in, &out, err) == LF_OK);
        int64_t n = 17;
        if (i < sizeof(small) / sizeof(*small)) {
            assert(lf_int_to_i64(&out, &n) && n == small[i]);
        } else {
            assert(!lf_int_to_i64(&out, &n) && n == 17);
        }
        assert(lf_int_to_dec(&out, &decimal, err) == LF_OK);
        assert(strcmp(decimal.ptr, cases[i]) == 0);
        lf_free(decimal.ptr);
        lf_int_free(&in);
        lf_int_free(&out);
    }
    lf_int out;
    assert(lf_int_from_dec("-", &out, err) == LF_INVALID);
    assert(lf_int_from_dec("+1", &out, err) == LF_INVALID);
    assert(lf_int_from_dec("-0009223372036854775809", &out, err) == LF_OK);
    assert(strcmp(out.decimal, "-9223372036854775809") == 0);
    lf_int_free(&out);
}

static void check_records(lf_error *err) {
    public_types_typed_mixed_nat mixed;
    assert(public_types_mixed(&mixed, err) == LF_OK);
    assert(mixed.switch_ && mixed.short_ == -1234);
    assert(mixed.text.len == sizeof("雪\0é") - 1);
    assert(memcmp(mixed.text.ptr, "雪\0é", mixed.text.len + 1) == 0);
    assert(mixed.count == UINT64_MAX && mixed.index == 191);
    assert(mixed.small_float == 0.25f && mixed.weight == -8.5);
    assert(mixed.color == public_types_typed_color_bright_blue);
    assert(mixed.single.data == INT64_MIN);
    assert(strcmp(mixed.holder.data.decimal,
                  "123456789012345678901234567890") == 0);
    bool equal = false;
    assert(public_types_check_mixed(&mixed, &equal, err) == LF_OK && equal);
    public_types_typed_mixed_nat_free(&mixed);
    public_types_typed_mixed_nat_free(&mixed);

    public_types_typed_color color = public_types_typed_color_red;
    assert(public_types_color(&color, &color, err) == LF_OK);
    assert(color == public_types_typed_color_red);
    const public_types_typed_color bad = (public_types_typed_color)99;
    assert(public_types_color(&bad, &color, err) == LF_INVALID);

    public_types_typed_empty empty;
    assert(public_types_empty(&empty, err) == LF_OK);
    public_types_typed_empty_free(&empty);

    public_types_typed_single_uint64 single = {UINT64_MAX};
    assert(public_types_single(&single, &single, err) == LF_OK);
    assert(single.data == UINT64_MAX);
    public_types_typed_single_uint64_free(&single);
}

static void check_trees(lf_error *err) {
    public_types_typed_tree tree;
    bool equal = false;
    assert(public_types_tree(&tree, err) == LF_OK);
    assert(tree.tag == public_types_typed_tree_fork);
    assert(tree.as.fork.left->tag == public_types_typed_tree_leaf);
    assert(strcmp(tree.as.fork.left->as.leaf.text.ptr, "木") == 0);
    assert(tree.as.fork.right->as.fork.left->tag ==
           public_types_typed_tree_empty);
    assert(strcmp(tree.as.fork.right->as.fork.right->as.leaf.text.ptr, "葉") ==
           0);
    assert(public_types_check_tree(&tree, &equal, err) == LF_OK && equal);
    public_types_typed_tree_free(&tree);
    public_types_typed_tree_free(&tree);

    public_types_typed_tree leaf = {.tag = public_types_typed_tree_leaf,
                                    .as.leaf.text = {"leaf", 4}};
    public_types_typed_tree malformed = {.tag = public_types_typed_tree_fork,
                                         .as.fork = {&leaf, NULL}};
    public_types_option_string out = {0};
    assert(public_types_multiple((lf_str){"earlier argument", 16}, &malformed,
                                 &out, err) == LF_INVALID);
    size_t before = live_blocks();
    for (size_t i = 0; i < 1000; ++i) {
        assert(public_types_multiple((lf_str){"earlier argument", 16},
                                     &malformed, &out, err) == LF_INVALID);
    }
    assert(live_blocks() == before);
}

static void check_collections(lf_error *err) {
    public_types_array_option_pair_nat_string empty = {0}, values, array;
    assert(public_types_arrays(&empty, &array, err) == LF_OK);
    assert(array.len == 0 && array.items == NULL);
    public_types_array_option_pair_nat_string_free(&array);
    assert(public_types_sample_array(&values, err) == LF_OK && values.len == 2);
    assert(public_types_arrays(&values, &array, err) == LF_OK);
    public_types_array_option_pair_nat_string_free(&values);
    assert(array.len == 2 && !array.items[1].has_value &&
           array.items[0].has_value);
    assert(array.items[0].value.fst.value == 17 &&
           array.items[0].value.fst.decimal == NULL);
    assert(strcmp(array.items[0].value.snd.ptr, "値") == 0);
    public_types_array_option_pair_nat_string_free(&array);
    assert(array.items == NULL && array.len == 0);

    lf_int ints[] = {lf_int_from_i64(-1), lf_int_from_i64(5),
                     lf_int_from_i64(0)};
    public_types_list_int list = {ints, 3}, list_out;
    assert(public_types_lists(&list, &list_out, err) == LF_OK);
    assert(list_out.len == 3 && list_out.items[0].value == -1 &&
           list_out.items[1].value == 5 && list_out.items[2].value == 0);
    public_types_list_int_free(&list_out);

    uint8_t raw[] = {0, 255, 128};
    lf_byte_array bytes = {raw, sizeof(raw)}, bytes_out;
    assert(public_types_bytes(&bytes, &bytes_out, err) == LF_OK);
    assert(bytes_out.len == sizeof(raw) &&
           memcmp(bytes_out.items, raw, sizeof(raw)) == 0);
    lf_byte_array_free(&bytes_out);

    public_types_option_option_bool option = {.has_value = true}, option_out;
    assert(public_types_options(&option, &option_out, err) == LF_OK);
    assert(option_out.has_value && !option_out.value.has_value);
    public_types_option_option_bool_free(&option_out);
    option.has_value = false;
    assert(public_types_options(&option, &option_out, err) == LF_OK);
    assert(!option_out.has_value);
    public_types_option_option_bool_free(&option_out);
}

static void check_except(lf_error *err) {
    public_types_option_nat out = {0};
    lf_nat code = lf_nat_from_u64(0);
    assert(public_types_checked(&code, &out, err) == LF_EXCEPT);
    assert(err->status == LF_EXCEPT &&
           strcmp(err->message, "\"noValue\"") == 0);
    code = lf_nat_from_u64(1);
    assert(public_types_checked(&code, &out, err) == LF_EXCEPT);
    assert(strcmp(err->message,
                  "{\"invalid\":{\"code\":123456789012345678901234567890,"
                  "\"message\":\"雪\\n\\\"\\u0000\"}}") == 0);
    assert(!out.has_value);
    assert(public_types_checked(&code, &out, NULL) == LF_EXCEPT);
    code = lf_nat_from_u64(2);
    assert(public_types_checked(&code, &out, err) == LF_IO);
    assert(strstr(err->message, "runtime error") != NULL);
    code = lf_nat_from_u64(3);
    assert(public_types_checked(&code, &out, err) == LF_OK);
    assert(out.has_value && out.value.value == 3);
    public_types_option_nat_free(&out);
    uint8_t small = 0;
    assert(public_types_positional(false, &small, err) == LF_EXCEPT);
    assert(strcmp(err->message, "{\"item\":[42,true]}") == 0 && small == 0);
    assert(public_types_positional(true, &small, err) == LF_OK && small == 13);

    assert(public_types_check_unit(true, err) == LF_OK);
    assert(public_types_check_unit(false, err) == LF_EXCEPT);
    assert(strcmp(err->message, "\"unit error\"") == 0);
}

static void check_floats(lf_error *err) {
    double raw[] = {1.5, -0.0, 0.1, 1e300, -1e-300, INFINITY, -INFINITY, NAN};
    size_t count = sizeof(raw) / sizeof(*raw);
    lf_float_array values = {raw, count}, out;
    assert(public_types_floats(&values, &out, err) == LF_OK);
    assert(out.len == count && memcmp(out.items, raw, sizeof(raw)) == 0);
    lf_float_array_free(&out);
    assert(out.items == NULL && out.len == 0);

    lf_float_array empty = {NULL, 0};
    assert(public_types_floats(&empty, &out, err) == LF_OK);
    assert(out.len == 0 && out.items == NULL);
    double sum = -1;
    assert(public_types_float_sum(&empty, &sum, err) == LF_OK && sum == 0);

    double addends[] = {1.0, 2.0, 4.0};
    lf_float_array three = {addends, 3};
    assert(public_types_float_sum(&three, &sum, err) == LF_OK && sum == 7);

    assert(public_types_float_make(9, &out, err) == LF_OK);
    assert(out.len == 2 && out.items[0] == 1.5 && out.items[1] == 9);
    lf_float_array_free(&out);

    public_types_typed_samples samples = {{addends, 3}, {"σ", 2}}, grown;
    assert(public_types_samples(&samples, &grown, err) == LF_OK);
    assert(grown.values.len == 4 && grown.values.items[0] == 1 &&
           grown.values.items[2] == 4 && grown.values.items[3] == 3);
    assert(grown.label.len == 2 && memcmp(grown.label.ptr, "σ", 2) == 0);
    public_types_typed_samples_free(&grown);

    lf_float_array dangling = {NULL, 3};
    assert(public_types_floats(&dangling, &out, err) == LF_INVALID);
    assert(strcmp(err->message, "Invalid FloatArray buffer or length") == 0);

    size_t before = live_blocks();
    for (size_t i = 0; i < 1000; ++i) {
        assert(public_types_floats(&values, &out, err) == LF_OK);
        lf_float_array_free(&out);
        assert(public_types_samples(&samples, &grown, err) == LF_OK);
        public_types_typed_samples_free(&grown);
    }
    assert(live_blocks() == before);
}

static void check_trivial(lf_error *err) {
    public_types_typed_wrap_text text = {.tag = public_types_typed_wrap_text_mk,
                                         .as.mk.text = {"雪", 3}};
    public_types_typed_wrap_text text_out;
    assert(public_types_wrap_text(&text, &text_out, err) == LF_OK);
    assert(text_out.tag == public_types_typed_wrap_text_mk &&
           strcmp(text_out.as.mk.text.ptr, "雪!") == 0);
    public_types_typed_wrap_text_free(&text_out);
    public_types_typed_wrap_text invalid = {
        .tag = public_types_typed_wrap_text_mk, .as.mk.text = {"a\xff", 2}};
    assert(public_types_wrap_text(&invalid, &text_out, err) == LF_INVALID);
    assert(strcmp(err->message, "Invalid UTF-8 string") == 0);
    public_types_typed_wrap_text_ref text_ref, text_ref_out;
    assert(public_types_typed_wrap_text_ref_from(&text, &text_ref, err) ==
           LF_OK);
    assert(public_types_wrap_text_ref(text_ref, &text_ref_out, err) == LF_OK);
    assert(public_types_typed_wrap_text_ref_get(text_ref_out, &text_out, err) ==
           LF_OK);
    assert(strcmp(text_out.as.mk.text.ptr, "雪!") == 0);
    public_types_typed_wrap_text_free(&text_out);
    public_types_typed_wrap_text_ref_release(text_ref);
    public_types_typed_wrap_text_ref_release(text_ref_out);

    for (unsigned i = 0; i < 256; ++i) {
        public_types_typed_wrap_byte byte = {
            .tag = public_types_typed_wrap_byte_mk, .as.mk.byte = (uint8_t)i};
        public_types_typed_wrap_byte byte_out;
        assert(public_types_wrap_byte(&byte, &byte_out, err) == LF_OK);
        assert(byte_out.tag == public_types_typed_wrap_byte_mk &&
               byte_out.as.mk.byte == (uint8_t)(i + 1));
    }
    const public_types_typed_wrap_byte bad_byte = {
        .tag = (public_types_typed_wrap_byte_tag)1};
    public_types_typed_wrap_byte byte_out;
    assert(public_types_wrap_byte(&bad_byte, &byte_out, err) == LF_INVALID);

    lf_nat nat_in;
    assert(lf_nat_from_dec("123456789012345678901234567890", &nat_in, err) ==
           LF_OK);
    public_types_typed_wrap_nat nat = {.tag = public_types_typed_wrap_nat_mk,
                                       .as.mk.a0 = nat_in};
    public_types_typed_wrap_nat nat_out;
    lf_str decimal;
    assert(public_types_wrap_nat(&nat, &nat_out, err) == LF_OK);
    assert(lf_nat_to_dec(&nat_out.as.mk.a0, &decimal, err) == LF_OK);
    assert(strcmp(decimal.ptr, "246913578024691357802469135780") == 0);
    lf_free(decimal.ptr);
    public_types_typed_wrap_nat_free(&nat_out);
    public_types_typed_wrap_nat_free(&nat);
    nat.as.mk.a0 = lf_nat_from_u64(21);
    assert(public_types_wrap_nat(&nat, &nat_out, err) == LF_OK);
    assert(nat_out.as.mk.a0.value == 42 && nat_out.as.mk.a0.decimal == NULL);
    public_types_typed_wrap_nat_free(&nat_out);

    public_types_typed_wrap_float weight = {
        .tag = public_types_typed_wrap_float_mk, .as.mk.value = -8.25};
    public_types_typed_wrap_float weight_out;
    assert(public_types_wrap_float(&weight, &weight_out, err) == LF_OK);
    assert(weight_out.as.mk.value == -7.75);

    public_types_typed_wrap_point point = {
        .tag = public_types_typed_wrap_point_mk,
        .as.mk.point = {UINT32_MAX - 1, {"点", 3}}};
    public_types_typed_wrap_point point_out;
    assert(public_types_wrap_point(&point, &point_out, err) == LF_OK);
    assert(point_out.as.mk.point.x == UINT32_MAX &&
           strcmp(point_out.as.mk.point.label.ptr, "点?") == 0);
    public_types_typed_wrap_point_free(&point_out);

    public_types_option_typed_bounded bounded;
    assert(public_types_bounded(9, &bounded, err) == LF_OK);
    assert(bounded.has_value &&
           bounded.value.tag == public_types_typed_bounded_mk &&
           bounded.value.as.mk.byte == 9);
    uint8_t byte_value = 0;
    assert(public_types_bounded_byte(&bounded.value, &byte_value, err) ==
               LF_OK &&
           byte_value == 9);
    assert(public_types_bounded(10, &bounded, err) == LF_OK &&
           !bounded.has_value);
    const public_types_typed_bounded too_large = {
        .tag = public_types_typed_bounded_mk, .as.mk.byte = 10};
    assert(public_types_bounded_byte(&too_large, &byte_value, err) ==
           LF_INVALID);
    assert(strcmp(err->message, "Invalid Typed.Bounded.small") == 0);

    public_types_typed_wrapped wrapped = {
        .text = text,
        .byte = {.tag = public_types_typed_wrap_byte_mk, .as.mk.byte = 200},
        .nat = {.tag = public_types_typed_wrap_nat_mk,
                .as.mk.a0 = lf_nat_from_u64(7)},
        .weight = weight,
        .point = point,
        .bounded = {.tag = public_types_typed_bounded_mk, .as.mk.byte = 3}};
    public_types_array_typed_wrapped all;
    assert(public_types_wrapped(&wrapped, &all, err) == LF_OK && all.len == 2);
    assert(strcmp(all.items[0].text.as.mk.text.ptr, "雪") == 0 &&
           strcmp(all.items[1].text.as.mk.text.ptr, "雪!") == 0);
    assert(all.items[0].byte.as.mk.byte == 200 &&
           all.items[1].byte.as.mk.byte == 201);
    assert(all.items[0].nat.as.mk.a0.value == 7 &&
           all.items[1].nat.as.mk.a0.value == 14);
    assert(all.items[0].weight.as.mk.value == -8.25 &&
           all.items[1].weight.as.mk.value == -7.75);
    assert(all.items[1].point.as.mk.point.x == UINT32_MAX &&
           strcmp(all.items[1].point.as.mk.point.label.ptr, "点?") == 0);
    assert(all.items[0].bounded.as.mk.byte == 3 &&
           all.items[1].bounded.as.mk.byte == 3);
    public_types_array_typed_wrapped_free(&all);
    wrapped.bounded.as.mk.byte = 11;
    assert(public_types_wrapped(&wrapped, &all, err) == LF_INVALID);
}

int main(void) {
    lf_error error = {0};
    assert(public_types_init(&error) == LF_OK);
    check_naturals(&error);
    check_integers(&error);
    check_records(&error);
    check_trees(&error);
    check_collections(&error);
    check_except(&error);
    check_floats(&error);
    check_trivial(&error);
    lf_error_clear(&error);
    return 0;
}
