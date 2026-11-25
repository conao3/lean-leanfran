#ifndef LEANFRAN_H
#define LEANFRAN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LEANFRAN_VERSION "0.11.1"

#ifdef __clang__
#define LF_STRUCT(name) __attribute__((annotate("leanfran", "struct", #name)))
#define LF_FIELD(...)                                                          \
    __attribute__((annotate("leanfran", "field", __VA_ARGS__)))
#else
#define LF_STRUCT(name)
#define LF_FIELD(...)
#endif

typedef enum {
    LF_OK,
    LF_INVALID,
    LF_EXCEPT,
    LF_IO,
    LF_NOT_INITIALIZED
} lf_status;

typedef struct {
    lf_status status;
    char *message;
} lf_error;

typedef struct {
    char *ptr;
    size_t len;
} lf_str;

typedef struct {
    uint64_t value;
    char *decimal;
} lf_nat;

typedef struct {
    int64_t value;
    char *decimal;
} lf_int;

typedef struct {
    uint8_t *items;
    size_t len;
} lf_byte_array;

typedef struct {
    uint8_t unused;
} lf_unit;

lf_nat lf_nat_from_u64(uint64_t value);
bool lf_nat_to_u64(const lf_nat *value, uint64_t *out);
lf_status lf_nat_from_dec(const char *decimal, lf_nat *out, lf_error *err);
lf_status lf_nat_to_dec(const lf_nat *value, lf_str *out, lf_error *err);
void lf_nat_free(lf_nat *value);

lf_int lf_int_from_i64(int64_t value);
bool lf_int_to_i64(const lf_int *value, int64_t *out);
lf_status lf_int_from_dec(const char *decimal, lf_int *out, lf_error *err);
lf_status lf_int_to_dec(const lf_int *value, lf_str *out, lf_error *err);
void lf_int_free(lf_int *value);

void lf_byte_array_free(lf_byte_array *value);
void lf_thread_attach(void);
void lf_thread_detach(void);
void lf_error_clear(lf_error *err);
void lf_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif
