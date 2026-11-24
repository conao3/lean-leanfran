#include <inttypes.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint64_t bits(double value) {
    uint64_t result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static double from_bits(uint64_t value) {
    double result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

#define OP(name) (strcmp(op, name) == 0)

#ifdef LEAN_MODEL

#include "model_ops.h"

static int evaluate(const char *kind, const char *op, uint64_t a, uint64_t b,
                    uint64_t *result) {
    lf_error error = {0};
    lf_str kind_arg = {(char *)kind, strlen(kind)};
    lf_str op_arg = {(char *)op, strlen(op)};
    lf_status status =
        model_ops_evaluate(kind_arg, op_arg, a, b, result, &error);
    if (status != LF_OK) {
        fprintf(stderr, "%s\n",
                error.message ? error.message : "Lean call failed");
        lf_error_clear(&error);
        return 1;
    }
    return 0;
}

#else

#define INTEGER_OPS(type)                                                      \
    do {                                                                       \
        type x = (type)a, y = (type)b;                                         \
        int64_t count = (int64_t)b;                                            \
        if (OP("add"))                                                         \
            return (uint64_t)(x + y);                                          \
        if (OP("sub"))                                                         \
            return (uint64_t)(x - y);                                          \
        if (OP("mul"))                                                         \
            return (uint64_t)(x * y);                                          \
        if (OP("neg"))                                                         \
            return (uint64_t)(type) - x;                                       \
        if (OP("div"))                                                         \
            return (uint64_t)(x / y);                                          \
        if (OP("mod"))                                                         \
            return (uint64_t)(x % y);                                          \
        if (OP("shl"))                                                         \
            return (uint64_t)(x << count);                                     \
        if (OP("shr"))                                                         \
            return (uint64_t)(x >> count);                                     \
        if (OP("and"))                                                         \
            return (uint64_t)(x & y);                                          \
        if (OP("or"))                                                          \
            return (uint64_t)(x | y);                                          \
        if (OP("xor"))                                                         \
            return (uint64_t)(x ^ y);                                          \
        if (OP("not"))                                                         \
            return (uint64_t)~x;                                               \
        if (OP("eq"))                                                          \
            return x == y;                                                     \
        if (OP("ne"))                                                          \
            return x != y;                                                     \
        if (OP("lt"))                                                          \
            return x < y;                                                      \
        if (OP("le"))                                                          \
            return x <= y;                                                     \
        if (OP("gt"))                                                          \
            return x > y;                                                      \
        if (OP("ge"))                                                          \
            return x >= y;                                                     \
        abort();                                                               \
    } while (0)

static uint64_t floating(const char *op, double x, double y) {
    if (OP("add"))
        return bits(x + y);
    if (OP("sub"))
        return bits(x - y);
    if (OP("mul"))
        return bits(x * y);
    if (OP("div"))
        return bits(x / y);
    if (OP("neg"))
        return bits(-x);
    if (OP("eq"))
        return x == y;
    if (OP("ne"))
        return x != y;
    if (OP("lt"))
        return x < y;
    if (OP("le"))
        return x <= y;
    if (OP("gt"))
        return x > y;
    if (OP("ge"))
        return x >= y;
    if (OP("bool"))
        return (bool)x;
    if (OP("i8"))
        return (uint64_t)(int8_t)x;
    if (OP("u8"))
        return (uint64_t)(uint8_t)x;
    if (OP("i16"))
        return (uint64_t)(int16_t)x;
    if (OP("u16"))
        return (uint64_t)(uint16_t)x;
    if (OP("i32"))
        return (uint64_t)(int32_t)x;
    if (OP("u32"))
        return (uint64_t)(uint32_t)x;
    if (OP("i64"))
        return (uint64_t)(int64_t)x;
    if (OP("u64"))
        return (uint64_t)x;
    if (OP("size"))
        return (size_t)x;
    abort();
}

static uint64_t convert(const char *op, uint64_t a) {
    int64_t x = (int64_t)a;
    if (OP("i8"))
        return (uint64_t)(int8_t)a;
    if (OP("u8"))
        return (uint8_t)x;
    if (OP("i16"))
        return (uint64_t)(int16_t)a;
    if (OP("u16"))
        return (uint16_t)x;
    if (OP("i32"))
        return (uint64_t)(int32_t)a;
    if (OP("u32"))
        return (uint32_t)x;
    if (OP("i64"))
        return (uint64_t)(int64_t)a;
    if (OP("u64"))
        return (uint64_t)x;
    if (OP("size"))
        return (size_t)x;
    if (OP("bool"))
        return (bool)x;
    if (OP("double_s"))
        return bits((double)x);
    if (OP("double_u"))
        return bits((double)a);
    if (OP("double_bool"))
        return bits((double)(bool)x);
    if (OP("promote"))
        return (uint64_t)((int8_t)x + (uint16_t)a);
    abort();
}

static uint64_t native(const char *kind, const char *op, uint64_t a,
                       uint64_t b) {
    if (strcmp(kind, "i32") == 0)
        INTEGER_OPS(int32_t);
    if (strcmp(kind, "i64") == 0)
        INTEGER_OPS(int64_t);
    if (strcmp(kind, "u32") == 0)
        INTEGER_OPS(uint32_t);
    if (strcmp(kind, "u64") == 0)
        INTEGER_OPS(uint64_t);
    if (strcmp(kind, "double") == 0)
        return floating(op, from_bits(a), from_bits(b));
    if (strcmp(kind, "cast") == 0)
        return convert(op, a);
    if (strcmp(kind, "index") == 0) {
        const uint64_t values[] = {a, ~a};
        return values[(int64_t)b];
    }
    if (strcmp(kind, "bool") == 0) {
        int64_t x = (int64_t)a, y = (int64_t)b;
        if (OP("and"))
            return x && x / y;
        if (OP("or"))
            return x || x / y;
        if (OP("not"))
            return !x;
    }
    abort();
}

static int evaluate(const char *kind, const char *op, uint64_t a, uint64_t b,
                    uint64_t *result) {
    *result = native(kind, op, a, b);
    return 0;
}

#endif

static int compare_output(const char *kind, const char *op, uint64_t a,
                          uint64_t b, bool double_result) {
    uint64_t result;
    if (evaluate(kind, op, a, b, &result) != 0) {
        fprintf(stderr, "%s %s %#" PRIx64 " %#" PRIx64 "\n", kind, op, a, b);
        return 1;
    }
    if (double_result && isnan(from_bits(result)))
        result = bits(NAN);
    printf("%s %s %#" PRIx64 " %#" PRIx64 " -> %#" PRIx64 "\n", kind, op, a, b,
           result);
    return 0;
}

static uint64_t next(void) {
    static uint64_t state = UINT64_C(0x75de20a931fbcd26);
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return state;
}

#define COUNT(array) (sizeof(array) / sizeof((array)[0]))

#define CHECK(kind, op, a, b)                                                  \
    do {                                                                       \
        if (compare_output(kind, op, a, b, false) != 0)                        \
            return 1;                                                          \
    } while (0)

static int integers(void) {
    const char *kinds[] = {"i32", "i64", "u32", "u64"};
    const char *ops[] = {"add", "sub", "mul", "neg", "div", "mod",
                         "shl", "shr", "and", "or",  "xor", "not",
                         "eq",  "ne",  "lt",  "le",  "gt",  "ge"};
    for (size_t k = 0; k < COUNT(kinds); ++k) {
        const char *kind = kinds[k];
        bool sign = kind[0] == 'i';
        unsigned width = kind[1] == '3' ? 32 : 64;
        uint64_t max = width == 32 ? INT32_MAX : INT64_MAX;
        uint64_t min = ~max;
        uint64_t all_bits = width == 32 ? UINT32_MAX : UINT64_MAX;
        const uint64_t edges[] = {0,   1,       (uint64_t)-1, max,
                                  min, min + 1, all_bits};
        for (size_t i = 0; i < COUNT(edges); ++i) {
            uint64_t edge = edges[i];
            CHECK(kind, "add", edge, 0);
            CHECK(kind, "sub", edge, 0);
            CHECK(kind, "mul", edge, 1);
            CHECK(kind, "div", edge, 1);
            CHECK(kind, "mod", edge, 7);
            CHECK(kind, "shr", edge, width - 1);
            CHECK(kind, "eq", edge, edge);
        }
        CHECK(kind, "shl", 1, width - (sign ? 2 : 1));
        CHECK(kind, "add", max - 1, 1);
        CHECK(kind, "sub", min + 1, 1);
        CHECK(kind, "div", -7, 3);
        CHECK(kind, "mod", -7, 3);
        CHECK(kind, "div", 7, -3);
        CHECK(kind, "mod", 7, -3);
        if (!sign) {
            CHECK(kind, "add", all_bits, 1);
            CHECK(kind, "sub", 0, 1);
            CHECK(kind, "mul", all_bits, all_bits);
            CHECK(kind, "neg", all_bits, 0);
        }
        for (unsigned sample = 0; sample < 256; ++sample) {
            uint64_t a = next();
            uint64_t b = next();
            for (size_t i = 0; i < COUNT(ops); ++i) {
                const char *op = ops[i];
                uint64_t x = a, y = b;
                if (OP("shl") || OP("shr")) {
                    y = b % width;
                    if (sign && OP("shl"))
                        x = y < width - 1 ? (a & max) >> y : 0;
                } else if (sign &&
                           (OP("add") || OP("sub") || OP("mul") || OP("neg"))) {
                    x = (uint64_t)((int64_t)(a & UINT16_MAX) - 32768);
                    y = (uint64_t)((int64_t)(b & UINT16_MAX) - 32768);
                } else if (OP("div") || OP("mod")) {
                    y |= 1;
                    if (sign && (x & all_bits) == (min & all_bits) &&
                        (y & all_bits) == all_bits)
                        y = 1;
                }
                CHECK(kind, op, x, y);
            }
        }
    }
    return 0;
}

static int floating_cases(void) {
    const char *arithmetic[] = {"add", "sub", "mul", "div", "neg"};
    const char *comparisons[] = {"eq", "ne", "lt", "le", "gt", "ge", "bool"};
    const char *targets[] = {"i8",  "u8",  "i16", "u16", "i32",
                             "u32", "i64", "u64", "size"};
    const double edges[] = {0.0,
                            -0.0,
                            0x1p-1074,
                            -0x1p-1022,
                            1.5,
                            -1.5,
                            0x1.fffffffffffffp1023,
                            INFINITY,
                            -INFINITY,
                            NAN};
    for (size_t a = 0; a < COUNT(edges); ++a) {
        for (size_t b = 0; b < COUNT(edges); ++b) {
            for (size_t i = 0; i < COUNT(arithmetic); ++i) {
                const char *op = arithmetic[i];
                if (compare_output("double", op, bits(edges[a]), bits(edges[b]),
                                   true) != 0)
                    return 1;
            }
            for (size_t i = 0; i < COUNT(comparisons); ++i)
                CHECK("double", comparisons[i], bits(edges[a]), bits(edges[b]));
        }
    }
    for (unsigned sample = 0; sample < 256; ++sample) {
        uint64_t a = next();
        uint64_t b = next();
        for (size_t i = 0; i < COUNT(arithmetic); ++i) {
            const char *op = arithmetic[i];
            if (compare_output("double", op, a, b, true) != 0)
                return 1;
        }
        for (size_t i = 0; i < COUNT(comparisons); ++i)
            CHECK("double", comparisons[i], a, b);
        for (size_t i = 0; i < COUNT(targets); ++i) {
            const char *op = targets[i];
            CHECK("double", op, bits((double)(a % 128) + 0.875), 0);
            CHECK("double", op,
                  bits(op[0] == 'i' ? -(double)(b % 129) - 0.5 : -0.5), 0);
        }
    }
    return 0;
}

static int casts_and_logic(void) {
    const char *casts[] = {"i8",          "u8",     "i16",      "u16",
                           "i32",         "u32",    "i64",      "u64",
                           "size",        "bool",   "double_s", "double_u",
                           "double_bool", "promote"};
    for (size_t i = 0; i < COUNT(casts); ++i) {
        const char *op = casts[i];
        CHECK("cast", op, 0, 0);
        CHECK("cast", op, UINT64_MAX, 0);
        CHECK("cast", op, INT64_MAX, 0);
        CHECK("cast", op, (uint64_t)INT64_MIN, 0);
        for (unsigned sample = 0; sample < 256; ++sample)
            CHECK("cast", op, next(), 0);
    }
    CHECK("bool", "and", 0, 0);
    CHECK("bool", "and", -1, -1);
    CHECK("bool", "and", 1, 2);
    CHECK("bool", "or", -1, 0);
    CHECK("bool", "or", 0, 1);
    CHECK("bool", "not", 0, 0);
    CHECK("bool", "not", -1, 0);
    CHECK("index", "read", 42, 0);
    CHECK("index", "read", 42, 1);

    CHECK("double", "i8", bits(-128.875), 0);
    CHECK("double", "i8", bits(127.875), 0);
    CHECK("double", "u8", bits(255.875), 0);
    CHECK("double", "i16", bits(-32768.875), 0);
    CHECK("double", "u16", bits(65535.875), 0);
    CHECK("double", "i32", bits(-2147483648.875), 0);
    CHECK("double", "u32", bits(4294967295.875), 0);
    CHECK("double", "i64", bits(-0x1p63), 0);
    CHECK("double", "i64", bits(0x1.fffffffffffffp62), 0);
    CHECK("double", "u64", bits(0x1.fffffffffffffp63), 0);
    CHECK("double", "size", bits((double)SIZE_MAX / 2), 0);
    return 0;
}

int main(int argc, char **argv) {
#ifdef LEAN_MODEL
    if (model_ops_init(NULL) != LF_OK)
        return 2;
#endif
    if (argc == 1)
        return integers() || floating_cases() || casts_and_logic();
    if (argc != 5)
        return 2;
    return compare_output(argv[1], argv[2], strtoull(argv[3], NULL, 0),
                          strtoull(argv[4], NULL, 0), false);
}
