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
    assert(invoice_type_uint32_ref_from(&two, &quantity, &err) == LF_OK);
    assert(invoice_invoice_price_ref_take(quantity, &result, &err) == LF_OK);
    uint32_t ref_total = 0;
    assert(invoice_type_uint32_ref_get(result, &ref_total, &err) == LF_OK);
    assert(ref_total == total);
    invoice_type_uint32_ref_release(result);
    printf("%u %u %u\n", (unsigned)base, (unsigned)total, (unsigned)minimum);
    lf_error_clear(&err);
    lf_thread_detach();
    return 0;
}
