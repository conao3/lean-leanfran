#include "leanfran.h"
#include <lean/lean.h>
#include <pthread.h>
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
