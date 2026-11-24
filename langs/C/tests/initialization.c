#include "public_api.h"

#include <assert.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>

static atomic_uint ready;
static atomic_bool start;

static void *initialize(void *unused) {
    (void)unused;
    atomic_fetch_add(&ready, 1);
    while (!atomic_load(&start)) {
        sched_yield();
    }
    assert(public_api_init(NULL) == LF_OK);
    return NULL;
}

int main(void) {
    pthread_t threads[8];
    for (size_t i = 0; i < 8; i++) {
        assert(pthread_create(&threads[i], NULL, initialize, NULL) == 0);
    }
    while (atomic_load(&ready) != 8) {
        sched_yield();
    }
    atomic_store(&start, true);
    for (size_t i = 0; i < 8; i++) {
        assert(pthread_join(threads[i], NULL) == 0);
    }
    assert(public_api_init(NULL) == LF_OK);
    uint64_t result;
    assert(public_api_counter(3, &result, NULL) == LF_OK);
    assert(result == 33);
}
