#include <fenv.h>
#include <stdio.h>
#include <stdlib.h>

#include "fixture.h"

int32_t counter = 0;

union number {
    int32_t i;
    float f;
};

int32_t pointer(int32_t *p) { return *p; }

int32_t heap(size_t n) { return malloc(n) != NULL; }

int32_t global(void) { return counter; }

int32_t static_local(void) {
    static int32_t n = 0;
    return n;
}

int32_t io(void) { return puts("x"); }

int32_t jump(int32_t a) {
    goto end;
end:
    return a;
}

int32_t fact(int32_t n) { return n <= 1 ? 1 : n * fact(n - 1); }

int32_t uses_fact(int32_t n) { return fact(n); }

int32_t variadic(int32_t n, ...) { return n; }

int32_t with_union(union number x) { return x.i; }

int32_t function_pointer(int32_t (*f)(int32_t)) { return f(1); }

int32_t volatile_local(void) {
    volatile int32_t x = 1;
    return x;
}

int32_t uninitialized(void) {
    int32_t x;
    x = 1;
    return x;
}

int32_t fallthrough(int32_t a) {
    switch (a) {
    case 1:
        a++;
    case 2:
        return a;
    }
    return 0;
}

int32_t early_break(int32_t a) {
    switch (a) {
    case 1:
        if (a > 0)
            break;
        a = 2;
        break;
    }
    return a;
}

int32_t string_literal(void) { return "ab"[0]; }

int32_t rounding(void) { return fegetround(); }

int32_t assign_value(int32_t a) {
    int32_t b = 0;
    return b = a;
}

int32_t increment_value(int32_t a) { return a++ + 1; }

int32_t comma(int32_t a) { return (a, 1); }

item set_field(item it) {
    it.qty = 2;
    return it;
}

shapes_geo_point literal(void) {
    shapes_geo_point p = {1, 2};
    return p;
}

float single(float x) { return x; }

char character(char c) { return c; }

int32_t mutable_array(int32_t *xs LF_ARRAY(n), size_t n) { return xs[0]; }

int32_t pass_array(const int32_t *xs LF_ARRAY(n), size_t n) {
    return mutable_array((int32_t *)xs, n);
}

lf_status out_value(int32_t *out) {
    *out = 1;
    return LF_OK;
}

int32_t address(void) {
    int32_t b = 0;
    return out_value(&b);
}

int32_t even(int32_t n);

int32_t odd(int32_t n) { return n == 0 ? 0 : even(n - 1); }

int32_t even(int32_t n) { return n == 0 ? 1 : odd(n - 1); }

int32_t short_circuit(int32_t a) {
    int32_t b = 0;
    return a > 0 && out_value(&b) == LF_OK;
}

int32_t head(const int32_t *xs LF_ARRAY(n), size_t n) {
    return n > 0 ? xs[0] : 0;
}

int32_t local_array(void) {
    int32_t b = 0;
    return head(&b, 1);
}

shapes_geo_color to_color(int32_t x) { return x; }

shapes_geo_color far_color(void) { return 7; }

shapes_geo_shape_rect_fields rect_of(shapes_geo_shape s) { return s.as.rect; }

lf_status overlap(const int32_t *xs LF_ARRAY(n), size_t n, int32_t *out) {
    if (n == 0)
        return LF_INVALID;
    *out = 0;
    *out = xs[0];
    return LF_OK;
}

lf_status byte_out(const int32_t *xs LF_ARRAY(n), size_t n, uint8_t *out) {
    if (n == 0)
        return LF_INVALID;
    *out = 0;
    if (xs[0] > 0)
        *out = 1;
    return LF_OK;
}

lf_status byte_array(const uint8_t *bs LF_ARRAY(n), size_t n, int32_t *out) {
    *out = (int32_t)n;
    return LF_OK;
}

lf_status sign_out(const int32_t *xs LF_ARRAY(n), size_t n, uint32_t *out) {
    *out = (uint32_t)n;
    return LF_OK;
}

lf_status enum_out(const uint32_t *xs LF_ARRAY(n), size_t n,
                   shapes_geo_color *out) {
    *out = shapes_geo_color_red;
    return LF_OK;
}

lf_status enum_array(const shapes_geo_color *cs LF_ARRAY(n), size_t n,
                     int32_t *out) {
    *out = (int32_t)n;
    return LF_OK;
}

lf_status struct_out(const int32_t *xs LF_ARRAY(n), size_t n,
                     shapes_geo_point p, shapes_geo_point *out) {
    *out = p;
    return LF_OK;
}

lf_status struct_array(const shapes_geo_point *ps LF_ARRAY(n), size_t n,
                       int32_t *out) {
    *out = (int32_t)n;
    return LF_OK;
}

lf_status union_out(const int64_t *xs LF_ARRAY(n), size_t n, shapes_geo_shape s,
                    shapes_geo_shape *out) {
    *out = s;
    return LF_OK;
}

lf_status union_array(const shapes_geo_shape *ss LF_ARRAY(n), size_t n,
                      shapes_geo_color *out) {
    *out = shapes_geo_color_red;
    return LF_OK;
}

lf_status byte_restrict(const int32_t *xs LF_ARRAY(n), size_t n,
                        uint8_t *restrict out) {
    *out = 1;
    return LF_OK;
}

lf_status union_restrict(const shapes_geo_shape *restrict ss LF_ARRAY(n),
                         size_t n, shapes_geo_color *out) {
    *out = shapes_geo_color_red;
    return LF_OK;
}

lf_status wide_out(const int32_t *xs LF_ARRAY(n), size_t n, int64_t *out) {
    *out = (int64_t)n;
    return LF_OK;
}

lf_status float_out(const int64_t *xs LF_ARRAY(n), size_t n, double *out) {
    *out = 1.0;
    return LF_OK;
}

lf_status bool_out(const int32_t *xs LF_ARRAY(n), size_t n, bool *out) {
    *out = n > 0;
    return LF_OK;
}

lf_status wide_enum(const int64_t *xs LF_ARRAY(n), size_t n,
                    shapes_geo_color *out) {
    *out = shapes_geo_color_red;
    return LF_OK;
}

lf_status wide_struct(const int64_t *xs LF_ARRAY(n), size_t n,
                      shapes_geo_point p, shapes_geo_point *out) {
    *out = p;
    return LF_OK;
}

uint64_t self_init(uint64_t p0) {
    {
        uint64_t p0 = p0 + 1;
        return p0;
    }
}
