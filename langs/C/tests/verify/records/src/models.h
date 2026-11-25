/* leanfran:lean shop
structure Point where
  x : Int32
  y : Int32

def lineSpec (o : order) : Int64 := o.price * Int64.ofInt o.qty.toNat
def sumSpec (p : Point) : Int64 := p.x.toInt64 + p.y.toInt64

inductive Size where
  | small
  | large

inductive Parcel where
  | box (w : Int32)
  | envelope

def sizeSpec (s : Size) : Int32 := match s with
  | .small => 1
  | .large => 5
def parcelSpec (p : Parcel) : Size := match p with
  | .box _ => .large
  | .envelope => .small
*/
#ifndef MODELS_H
#define MODELS_H
#include "leanfran.h"

typedef struct LF_STRUCT(shop) order {
    uint32_t qty LF_FIELD("ge=1", "le=1000");
    int64_t price LF_FIELD("ge=0", "le=1000000");
} order;

#endif
