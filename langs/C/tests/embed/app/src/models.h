#ifndef APP_MODELS_H
#define APP_MODELS_H

#include "leanfran.h"

typedef struct LF_STRUCT(pricing) order {
    uint32_t qty LF_FIELD("ge=1", "le=1000");
    int64_t price_cents LF_FIELD("ge=0");
    lf_str sku LF_FIELD("min_len=1", "max_len=8");
} order;

typedef struct {
    order *items;
    size_t len;
} order_list;

typedef struct LF_STRUCT(pricing) {
    order_list orders LF_FIELD("max_len=4");
    bool express;
} cart;

#endif

/* leanfran:lean pricing
def orderTotal (o : order) : Int :=
  Int.ofNat o.qty.toNat * o.price_cents.toInt

def cartTotal (c : cart) : Int :=
  c.orders.foldl (fun acc o => acc + orderTotal o) (if c.express then 500 else
0)

def sampleOrder : order :=
  ⟨2, by decide, by decide, 125, by decide, "A1", by decide, by decide⟩

theorem sampleOrder_total : orderTotal sampleOrder = 250 := by decide
*/
