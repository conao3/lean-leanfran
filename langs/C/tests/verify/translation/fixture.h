#ifndef FIXTURE_H
#define FIXTURE_H

#include "leanfran.h"
#include "shapes.h"

typedef struct LF_STRUCT(fixture) item {
    uint32_t qty LF_FIELD("ge=1");
    int64_t price;
    size_t weight;
} item;

#endif
