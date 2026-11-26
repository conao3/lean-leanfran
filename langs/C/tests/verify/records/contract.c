#include "grade.h"
#include "shop.h"
#include <inttypes.h>
#include <stdio.h>

int64_t line_total(order o);

static void report(const char *name, bool valid, lf_error *error) {
    printf("%s: %s\n", name, valid ? "valid" : error->message);
    lf_error_clear(error);
}

int main(void) {
    lf_error error = {0};
    if (shop_init(&error) != LF_OK || grade_init(&error) != LF_OK) {
        fprintf(stderr, "%s\n", error.message);
        return 1;
    }
    order large = {.qty = 4000000000u, .price = 9000000000000000000LL};
    report("large order", shop_order_valid(&large, &error), &error);
    order small = {.qty = 3, .price = 1200};
    report("small order", shop_order_valid(&small, &error), &error);
    printf("line_total = %" PRId64 "\n", line_total(small));
    grade_level level = (grade_level)7;
    report("level 7", grade_level_valid(&level, &error), &error);
    return 0;
}
