#ifndef LEANFRAN_H
#define LEANFRAN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LEANFRAN_VERSION "0.10.0"

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

void lf_error_clear(lf_error *err);
void lf_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif
