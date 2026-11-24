#include "leanfran.h"
#include <errno.h>
#include <inttypes.h>
#include <lean/lean.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern lean_object *lean_io_error_to_string(lean_object *error);

static pthread_mutex_t initialization_lock = PTHREAD_MUTEX_INITIALIZER;
static bool task_manager_started;

void lf_free(void *ptr) { free(ptr); }

void lf_error_clear(lf_error *err) {
    if (err != NULL) {
        lf_free(err->message);
        err->status = LF_OK;
        err->message = NULL;
    }
}

static char *copy_bytes(const char *ptr, size_t len) {
    if (len == SIZE_MAX) {
        return NULL;
    }
    char *copy = malloc(len + 1);
    if (copy != NULL) {
        memcpy(copy, ptr, len);
        copy[len] = '\0';
    }
    return copy;
}

lf_status lf_set_error(lf_error *err, lf_status status, const char *message) {
    lf_error_clear(err);
    if (err != NULL) {
        err->status = status;
        err->message = copy_bytes(message, strlen(message));
    }
    return status;
}

lf_status lf_copy_string(b_lean_obj_arg value, lf_str *out, lf_error *err) {
    size_t len = lean_string_size(value) - 1;
    char *ptr = copy_bytes(lean_string_cstr(value), len);
    if (ptr == NULL) {
        return lf_set_error(err, LF_IO, "Could not allocate output string");
    }
    *out = (lf_str){ptr, len};
    return LF_OK;
}

lf_status lf_copy_io_error(b_lean_obj_arg result, lf_error *err) {
    lean_object *error = lean_io_result_get_error(result);
    lean_inc(error);
    lean_object *message = lean_io_error_to_string(error);
    lf_status status = lf_set_error(err, LF_IO, lean_string_cstr(message));
    lean_dec(message);
    return status;
}

void lf_initialize(lean_object *(*initialize)(void), lf_error *err) {
    pthread_mutex_lock(&initialization_lock);
    lean_object *result = initialize();
    if (lean_io_result_is_error(result)) {
        lf_copy_io_error(result, err);
    } else if (!task_manager_started) {
        lean_io_mark_end_initialization();
        lean_init_task_manager();
        task_manager_started = true;
    }
    lean_dec(result);
    pthread_mutex_unlock(&initialization_lock);
}

lf_nat lf_nat_from_u64(uint64_t value) { return (lf_nat){.value = value}; }

bool lf_nat_to_u64(const lf_nat *value, uint64_t *out) {
    if (value == NULL || value->decimal != NULL || out == NULL) {
        return false;
    }
    *out = value->value;
    return true;
}

lf_int lf_int_from_i64(int64_t value) { return (lf_int){.value = value}; }

bool lf_int_to_i64(const lf_int *value, int64_t *out) {
    if (value == NULL || value->decimal != NULL || out == NULL) {
        return false;
    }
    *out = value->value;
    return true;
}

static bool valid_decimal(const char *decimal, bool is_signed) {
    if (decimal == NULL) {
        return false;
    }
    if (is_signed && *decimal == '-') {
        ++decimal;
    }
    if (*decimal == '\0') {
        return false;
    }
    for (; *decimal != '\0'; ++decimal) {
        if (*decimal < '0' || *decimal > '9') {
            return false;
        }
    }
    return true;
}

static lf_status copy_decimal(const char *decimal, lf_str *out, lf_error *err) {
    size_t len = strlen(decimal);
    char *ptr = copy_bytes(decimal, len);
    if (ptr == NULL) {
        return lf_set_error(err, LF_IO, "Could not allocate a decimal string");
    }
    *out = (lf_str){ptr, len};
    return LF_OK;
}

lf_status lf_nat_from_dec(const char *decimal, lf_nat *out, lf_error *err) {
    if (out == NULL || !valid_decimal(decimal, false)) {
        return lf_set_error(err, LF_INVALID,
                            "Expected a Nat decimal and an output pointer");
    }
    errno = 0;
    uintmax_t n = strtoumax(decimal, NULL, 10);
    if (errno != ERANGE && n <= UINT64_MAX) {
        *out = lf_nat_from_u64((uint64_t)n);
        return LF_OK;
    }
    while (*decimal == '0') {
        ++decimal;
    }
    char *copy = copy_bytes(decimal, strlen(decimal));
    if (copy == NULL) {
        return lf_set_error(err, LF_IO, "Could not allocate a decimal string");
    }
    *out = (lf_nat){.decimal = copy};
    return LF_OK;
}

lf_status lf_int_from_dec(const char *decimal, lf_int *out, lf_error *err) {
    if (out == NULL || !valid_decimal(decimal, true)) {
        return lf_set_error(err, LF_INVALID,
                            "Expected an Int decimal and an output pointer");
    }
    errno = 0;
    intmax_t n = strtoimax(decimal, NULL, 10);
    if (errno != ERANGE && n >= INT64_MIN && n <= INT64_MAX) {
        *out = lf_int_from_i64((int64_t)n);
        return LF_OK;
    }
    bool negative = *decimal == '-';
    decimal += negative;
    while (*decimal == '0') {
        ++decimal;
    }
    size_t len = strlen(decimal);
    if (len > SIZE_MAX - 2) {
        return lf_set_error(err, LF_IO, "Could not allocate a decimal string");
    }
    char *copy = malloc(len + 1 + negative);
    if (copy == NULL) {
        return lf_set_error(err, LF_IO, "Could not allocate a decimal string");
    }
    if (negative) {
        copy[0] = '-';
    }
    memcpy(copy + negative, decimal, len + 1);
    *out = (lf_int){.decimal = copy};
    return LF_OK;
}

lf_status lf_nat_to_dec(const lf_nat *value, lf_str *out, lf_error *err) {
    if (value == NULL || out == NULL) {
        return lf_set_error(err, LF_INVALID,
                            "Expected a Nat and an output pointer");
    }
    char buf[32];
    if (value->decimal == NULL) {
        snprintf(buf, sizeof(buf), "%" PRIu64, value->value);
    } else if (!valid_decimal(value->decimal, false)) {
        return lf_set_error(err, LF_INVALID, "Invalid Nat decimal");
    }
    return copy_decimal(value->decimal == NULL ? buf : value->decimal, out,
                        err);
}

lf_status lf_int_to_dec(const lf_int *value, lf_str *out, lf_error *err) {
    if (value == NULL || out == NULL) {
        return lf_set_error(err, LF_INVALID,
                            "Expected an Int and an output pointer");
    }
    char buf[32];
    if (value->decimal == NULL) {
        snprintf(buf, sizeof(buf), "%" PRId64, value->value);
    } else if (!valid_decimal(value->decimal, true)) {
        return lf_set_error(err, LF_INVALID, "Invalid Int decimal");
    }
    return copy_decimal(value->decimal == NULL ? buf : value->decimal, out,
                        err);
}

void lf_nat_free(lf_nat *value) {
    if (value != NULL) {
        free(value->decimal);
        *value = (lf_nat){0};
    }
}

void lf_int_free(lf_int *value) {
    if (value != NULL) {
        free(value->decimal);
        *value = (lf_int){0};
    }
}

void lf_byte_array_free(lf_byte_array *value) {
    if (value != NULL) {
        free(value->items);
        *value = (lf_byte_array){0};
    }
}

lf_status lf_nat_to_lean(const lf_nat *in, lean_object **out, lf_error *err) {
    if (in->decimal != NULL && !valid_decimal(in->decimal, false)) {
        return lf_set_error(err, LF_INVALID, "Invalid Nat decimal");
    }
    *out = in->decimal == NULL ? lean_uint64_to_nat(in->value)
                               : lean_cstr_to_nat(in->decimal);
    return LF_OK;
}

lf_status lf_int_to_lean(const lf_int *in, lean_object **out, lf_error *err) {
    if (in->decimal != NULL && !valid_decimal(in->decimal, true)) {
        return lf_set_error(err, LF_INVALID, "Invalid Int decimal");
    }
    *out = in->decimal == NULL ? lean_int64_to_int(in->value)
                               : lean_cstr_to_int(in->decimal);
    return LF_OK;
}

lf_status lf_byte_array_to_lean(const lf_byte_array *in, lean_object **out,
                                lf_error *err) {
    if ((in->len != 0 && in->items == NULL) ||
        lean_alloc_sarray_would_overflow(1, in->len)) {
        return lf_set_error(err, LF_INVALID,
                            "Invalid ByteArray buffer or length");
    }
    *out = lean_alloc_sarray(1, in->len, in->len);
    if (in->len != 0) {
        memcpy(lean_sarray_cptr(*out), in->items, in->len);
    }
    return LF_OK;
}

lf_status lf_byte_array_from_lean(b_lean_obj_arg in, lf_byte_array *out,
                                  lf_error *err) {
    size_t len = lean_sarray_size(in);
    uint8_t *items = NULL;
    if (len != 0) {
        items = malloc(len);
        if (items == NULL) {
            return lf_set_error(err, LF_IO, "Could not allocate a ByteArray");
        }
        memcpy(items, lean_sarray_cptr(in), len);
    }
    *out = (lf_byte_array){items, len};
    return LF_OK;
}

bool lf_nat_from_lean_u64(b_lean_obj_arg in, uint64_t *out) {
    lean_object *max = lean_uint64_to_nat(UINT64_MAX);
    bool fits = lean_nat_le(in, max);
    lean_dec(max);
    if (fits) {
        *out = lean_uint64_of_nat(in);
    }
    return fits;
}

bool lf_int_from_lean_i64(b_lean_obj_arg in, int64_t *out) {
    lean_object *min = lean_int64_to_int(INT64_MIN);
    lean_object *max = lean_int64_to_int(INT64_MAX);
    bool fits = lean_int_le(min, in) && lean_int_le(in, max);
    lean_dec(min);
    lean_dec(max);
    if (fits) {
        uint64_t bits = lean_int64_of_int(in);
        memcpy(out, &bits, sizeof(bits));
    }
    return fits;
}
