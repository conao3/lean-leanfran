#include <inttypes.h>
#include <locale.h>
#include <math.h>
#include <stdio.h>

typedef struct {
    char *ptr;
    size_t len;
    size_t capacity;
} lf_json_buffer;

static bool lf_json_append(lf_json_buffer *out, const char *text, size_t len) {
    if (len >= SIZE_MAX - out->len) {
        return false;
    }
    size_t needed = out->len + len + 1;
    if (needed > out->capacity) {
        size_t next =
            out->capacity > SIZE_MAX / 2 ? SIZE_MAX : out->capacity * 2;
        char *ptr = realloc(out->ptr, next < needed ? needed : next);
        if (ptr == NULL) {
            return false;
        }
        out->ptr = ptr;
        out->capacity = next < needed ? needed : next;
    }
    memcpy(out->ptr + out->len, text, len);
    out->len += len;
    out->ptr[out->len] = '\0';
    return true;
}

static bool lf_json_literal(lf_json_buffer *out, const char *text) {
    return lf_json_append(out, text, strlen(text));
}

static inline bool lf_json_string(lf_json_buffer *out, const char *ptr,
                                  size_t len) {
    if (!lf_json_literal(out, "\"")) {
        return false;
    }
    for (size_t i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)ptr[i];
        const char *escaped = NULL;
        switch (c) {
        case '"':
            escaped = "\\\"";
            break;
        case '\\':
            escaped = "\\\\";
            break;
        case '\n':
            escaped = "\\n";
            break;
        case '\r':
            escaped = "\\r";
            break;
        }
        if (escaped != NULL) {
            if (!lf_json_append(out, escaped, 2)) {
                return false;
            }
        } else if (c < 0x20) {
            char buf[7];
            snprintf(buf, sizeof(buf), "\\u%04x", (unsigned)c);
            if (!lf_json_append(out, buf, 6)) {
                return false;
            }
        } else if (!lf_json_append(out, ptr + i, 1)) {
            return false;
        }
    }
    return lf_json_literal(out, "\"");
}

static inline bool lf_json_char(lf_json_buffer *out, uint32_t c) {
    char bytes[4];
    size_t len;
    if (c < 0x80) {
        bytes[0] = (char)c;
        len = 1;
    } else if (c < 0x800) {
        bytes[0] = (char)(0xc0 | c >> 6);
        bytes[1] = (char)(0x80 | (c & 0x3f));
        len = 2;
    } else if (c < 0x10000) {
        bytes[0] = (char)(0xe0 | c >> 12);
        bytes[1] = (char)(0x80 | (c >> 6 & 0x3f));
        bytes[2] = (char)(0x80 | (c & 0x3f));
        len = 3;
    } else {
        bytes[0] = (char)(0xf0 | c >> 18);
        bytes[1] = (char)(0x80 | (c >> 12 & 0x3f));
        bytes[2] = (char)(0x80 | (c >> 6 & 0x3f));
        bytes[3] = (char)(0x80 | (c & 0x3f));
        len = 4;
    }
    return lf_json_string(out, bytes, len);
}

static inline bool lf_json_unsigned(lf_json_buffer *out, uint64_t value,
                                    bool quoted) {
    char buf[32];
    int len = snprintf(buf, sizeof(buf), "%" PRIu64, value);
    return quoted ? lf_json_string(out, buf, (size_t)len)
                  : lf_json_append(out, buf, (size_t)len);
}

static inline bool lf_json_signed(lf_json_buffer *out, int64_t value) {
    char buf[32];
    int len = snprintf(buf, sizeof(buf), "%" PRId64, value);
    return lf_json_append(out, buf, (size_t)len);
}

static inline bool lf_json_float(lf_json_buffer *out, double value,
                                 int precision) {
    if (isnan(value)) {
        return lf_json_literal(out, "\"NaN\"");
    }
    if (isinf(value)) {
        return lf_json_literal(out,
                               value < 0 ? "\"-Infinity\"" : "\"Infinity\"");
    }
    char buf[64];
    int len = snprintf(buf, sizeof(buf), "%.*g", precision, value);
    if (len < 0 || (size_t)len >= sizeof(buf)) {
        return false;
    }
    const char *point = localeconv()->decimal_point;
    if (strcmp(point, ".") != 0) {
        char *pos = strstr(buf, point);
        if (pos != NULL) {
            return lf_json_append(out, buf, (size_t)(pos - buf)) &&
                   lf_json_literal(out, ".") &&
                   lf_json_literal(out, pos + strlen(point));
        }
    }
    return lf_json_append(out, buf, (size_t)len);
}
