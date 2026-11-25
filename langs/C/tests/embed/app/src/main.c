#include "catalog.h"
#include "invoice.h"
#include "limits.h"
#include "pricing.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

/* leanfran:lean invoice
imports: catalog, limits
def invoicePrice (quantity : UInt32) : UInt32 := quantity * basePrice +
minimumPrice

theorem invoice_checked : invoicePrice 2 = 46 := by decide
*/

int main(void) {
    const char *literal = "/* leanfran:lean invoice";
    assert(*literal == '/');

    lf_error err = {0};
    uint32_t base = 0, total = 0, minimum = 0;
    assert(invoice_invoice_price(2, &total, &err) == LF_NOT_INITIALIZED);
    lf_str json = {0};
    assert(invoice_uint32_to_json(&total, &json, &err) == LF_NOT_INITIALIZED);
    invoice_type_uint32_ref quantity, result;
    const uint32_t two = 2;
    assert(invoice_type_uint32_ref_from(&two, &quantity, &err) ==
           LF_NOT_INITIALIZED);
    assert(leanfran_init(&err) == LF_OK);
    assert(catalog_base_price(&base, &err) == LF_OK);
    assert(limits_minimum_price(&minimum, &err) == LF_OK);
    assert(invoice_invoice_price(2, &total, &err) == LF_OK);
    assert(catalog_init(&err) == LF_OK);
    assert(invoice_init(&err) == LF_OK);
    assert(invoice_uint32_to_json(&total, &json, &err) == LF_OK);
    uint32_t decoded = 0;
    assert(invoice_uint32_from_json(json.ptr, json.len, &decoded, &err) ==
           LF_OK);
    assert(decoded == total);
    lf_free(json.ptr);
    assert(invoice_type_uint32_ref_from(&two, &quantity, &err) == LF_OK);
    assert(invoice_invoice_price_ref_take(quantity, &result, &err) == LF_OK);
    uint32_t ref_total = 0;
    assert(invoice_type_uint32_ref_get(result, &ref_total, &err) == LF_OK);
    assert(ref_total == total);
    invoice_type_uint32_ref_release(result);
    char sku[] = "A7";
    order orders[2] = {{.qty = 3, .price_cents = 250, .sku = {sku, 2}},
                       {.qty = 1, .price_cents = 1000, .sku = {sku, 2}}};
    cart basket = {.orders = {orders, 2}, .express = true};
    lf_int amount = {0};
    int64_t cents = 0;
    assert(pricing_cart_total(&basket, &amount, &err) == LF_OK);
    assert(lf_int_to_i64(&amount, &cents) && cents == 2250);
    order sample = {0};
    assert(pricing_sample_order(&sample, &err) == LF_OK);
    assert(sample.qty == 2 && sample.price_cents == 125 &&
           sample.sku.len == 2 && memcmp(sample.sku.ptr, "A1", 2) == 0);
    assert(pricing_order_total(&sample, &amount, &err) == LF_OK);
    assert(lf_int_to_i64(&amount, &cents) && cents == 250);
    pricing_order_free(&sample);
    lf_str encoded = {0};
    assert(pricing_cart_to_json(&basket, &encoded, &err) == LF_OK);
    printf("%.*s\n", (int)encoded.len, encoded.ptr);
    lf_free(encoded.ptr);
    orders[1].qty = 0;
    assert(pricing_cart_total(&basket, &amount, &err) == LF_INVALID);
    printf("%s\n", err.message);
    orders[1].qty = 1;
    orders[0].sku.len = 0;
    assert(!pricing_order_valid(&orders[0], &err));
    printf("%s\n", err.message);
    orders[0].sku.len = 2;
    basket.orders.len = 5;
    order many[5] = {orders[0], orders[0], orders[0], orders[0], orders[0]};
    basket.orders.items = many;
    assert(pricing_cart_total(&basket, &amount, &err) == LF_INVALID);
    printf("%s\n", err.message);
    printf("%u %u %u\n", (unsigned)base, (unsigned)total, (unsigned)minimum);
    lf_error_clear(&err);
    lf_thread_detach();
    return 0;
}
