#include "lean_import.h"
#include <string.h>

int main(void) {
    lf_str output;
    if (lean_import_init(NULL) != LF_OK ||
        lean_import_encode(42, &output, NULL) != LF_OK) {
        return 1;
    }
    int result = strcmp(output.ptr, "42") != 0;
    lf_free(output.ptr);
    return result;
}
