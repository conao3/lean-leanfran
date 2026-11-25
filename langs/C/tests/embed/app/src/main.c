#include "catalog.h"
#include "invoice.h"
#include "limits.h"
#include <assert.h>
#include <stdio.h>

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
    printf("%u %u %u\n", (unsigned)base, (unsigned)total, (unsigned)minimum);
    lf_error_clear(&err);
    return 0;
}
