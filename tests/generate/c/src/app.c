/* leanfran:lean app
import Shapes.Area

def rectArea (w h : UInt64) : UInt64 :=
  (Shapes.Area.area ⟨⟨0, 0⟩, w.toNat, h.toNat⟩).toUInt64
*/
#include "app.h"
#include "extra.h"
#include <inttypes.h>
#include <stdio.h>

int main(void) {
    lf_error err = {0};
    uint64_t area = 0, doubled = 0;
    if (leanfran_init(&err) != LF_OK ||
        app_rect_area(3, 4, &area, &err) != LF_OK ||
        extra_twice(area, &doubled, &err) != LF_OK) {
        fprintf(stderr, "embed: %s\n", err.message);
        return 1;
    }
    printf("area=%" PRIu64 " doubled=%" PRIu64 "\n", area, doubled);
    return 0;
}
