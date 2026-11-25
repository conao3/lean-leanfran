#include "shop.h"
#include "models.h"

LF_MODEL("refines=lineSpec", "spec=shop")
int64_t line_total(order o) { return o.price * (int64_t)o.qty; }

LF_MODEL("refines=sumSpec", "spec=shop")
int64_t point_sum(shop_point p) {
#ifdef SHOP_FIRST
    return (int64_t)p.x + (int64_t)p.y;
#else
    return (int64_t)p.x - (int64_t)p.y;
#endif
}

LF_MODEL("refines=sizeSpec", "spec=shop")
int32_t size_weight(shop_size s) {
    switch (s) {
    case shop_size_small:
        return 1;
    default:
        return 5;
    }
}

LF_MODEL("refines=parcelSpec", "spec=shop")
shop_size parcel_size(shop_parcel p) {
    if (p.tag == shop_parcel_box)
        return shop_size_large;
    return shop_size_small;
}
