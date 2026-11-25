#ifndef LEANFRAN_MODEL_TEST_H
#define LEANFRAN_MODEL_TEST_H

#include "leanfran.h"
#include <float.h>
#include <inttypes.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LF_MODEL_MAX_LENGTH 8

typedef struct {
    uint64_t state;
} lf_model_rng;

static inline uint64_t lf_model_next(lf_model_rng *rng) {
    uint64_t z = (rng->state += UINT64_C(0x9e3779b97f4a7c15));
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}

static inline lf_model_rng lf_model_rng_new(uint64_t seed, const char *name) {
    uint64_t hash = UINT64_C(0xcbf29ce484222325);
    for (const char *c = name; *c; c++)
        hash = (hash ^ (uint8_t)*c) * UINT64_C(0x100000001b3);
    lf_model_rng rng = {seed ^ hash};
    return rng;
}

static inline uint64_t lf_model_env(const char *name, uint64_t fallback) {
    const char *value = getenv(name);
    if (value == NULL || *value == '\0')
        return fallback;
    char *end = NULL;
    unsigned long long parsed = strtoull(value, &end, 10);
    if (*end != '\0') {
        fprintf(stderr, "leanfran_model_test: %s must be a decimal number\n",
                name);
        exit(2);
    }
    return (uint64_t)parsed;
}

static inline uint64_t lf_model_cases(uint64_t total, uint64_t count) {
    return total > UINT64_MAX / count ? UINT64_MAX : total * count;
}

static inline bool lf_model_pick(uint64_t *pick, uint64_t count,
                                 uint64_t *index) {
    if (pick == NULL)
        return false;
    *index = *pick % count;
    *pick /= count;
    return true;
}

#define LF_MODEL_SIGNED_CASES 9
#define LF_MODEL_UNSIGNED_CASES 5
#define LF_MODEL_BOOL_CASES 2
#define LF_MODEL_DOUBLE_CASES 12

static inline int64_t lf_model_signed(lf_model_rng *rng, unsigned width,
                                      uint64_t *pick) {
    int64_t max = (int64_t)((UINT64_C(1) << (width - 1)) - 1);
    int64_t min = -max - 1;
    int64_t cases[LF_MODEL_SIGNED_CASES] = {0,   1,       -1,      2,  -2,
                                            min, min + 1, max - 1, max};
    uint64_t index;
    if (lf_model_pick(pick, LF_MODEL_SIGNED_CASES, &index))
        return cases[index];
    uint64_t bits = lf_model_next(rng);
    switch (bits % 4) {
    case 0:
        return cases[(bits >> 8) % LF_MODEL_SIGNED_CASES];
    case 1:
        return (int64_t)((bits >> 8) % 33) - 16;
    default: {
        uint64_t value = lf_model_next(rng);
        if (width < 64) {
            value &= (UINT64_C(1) << width) - 1;
            if (value >> (width - 1))
                return (int64_t)(value - (UINT64_C(1) << (width - 1))) + min;
        }
        return (int64_t)value;
    }
    }
}

static inline uint64_t lf_model_unsigned(lf_model_rng *rng, unsigned width,
                                         uint64_t *pick) {
    uint64_t max = width == 64 ? UINT64_MAX : (UINT64_C(1) << width) - 1;
    uint64_t cases[LF_MODEL_UNSIGNED_CASES] = {0, 1, 2, max - 1, max};
    uint64_t index;
    if (lf_model_pick(pick, LF_MODEL_UNSIGNED_CASES, &index))
        return cases[index];
    uint64_t bits = lf_model_next(rng);
    switch (bits % 4) {
    case 0:
        return cases[(bits >> 8) % LF_MODEL_UNSIGNED_CASES];
    case 1:
        return (bits >> 8) % 33;
    default:
        return lf_model_next(rng) & max;
    }
}

static inline bool lf_model_bool(lf_model_rng *rng, uint64_t *pick) {
    uint64_t index;
    if (lf_model_pick(pick, LF_MODEL_BOOL_CASES, &index))
        return index == 1;
    return lf_model_next(rng) & 1;
}

static inline double lf_model_double(lf_model_rng *rng, uint64_t *pick) {
    double cases[LF_MODEL_DOUBLE_CASES] = {
        0.0,       -0.0, 1.0,     -1.0,     0.5,     INFINITY,
        -INFINITY, NAN,  DBL_MAX, -DBL_MAX, DBL_MIN, 4.9e-324};
    uint64_t index;
    if (lf_model_pick(pick, LF_MODEL_DOUBLE_CASES, &index))
        return cases[index];
    uint64_t bits = lf_model_next(rng);
    switch (bits % 4) {
    case 0:
        return cases[(bits >> 8) % LF_MODEL_DOUBLE_CASES];
    case 1:
        return (double)((int64_t)((bits >> 8) % 65) - 32) / 4.0;
    default: {
        uint64_t raw = lf_model_next(rng);
        double value;
        memcpy(&value, &raw, sizeof value);
        return value;
    }
    }
}

static inline size_t lf_model_length(lf_model_rng *rng) {
    return (size_t)(lf_model_next(rng) % (LF_MODEL_MAX_LENGTH + 1));
}

static inline bool lf_model_same_double(double a, double b) {
    if (isnan(a) && isnan(b))
        return true;
    return memcmp(&a, &b, sizeof a) == 0;
}

static inline int lf_model_lean_error(const char *function, const char *call,
                                      lf_error *err) {
    fprintf(stderr, "%s: %s failed: %s\n", function, call,
            err->message ? err->message : "unknown error");
    lf_error_clear(err);
    return 1;
}

#endif
