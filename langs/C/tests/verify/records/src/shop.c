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
