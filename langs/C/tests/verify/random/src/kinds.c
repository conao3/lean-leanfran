/* leanfran:lean kinds
inductive Level where
  | low
  | mid
  | high

inductive Shape where
  | circle (r : Int32)
  | rect (w h : Int32) (level : Level)
  | dot
  | ring (r : Int32) (pos : 0 ≤ r)

inductive Proven where
  | mk (n : Int32) (small : n < 10)

def levelOf (x : Int32) : Level :=
  if x < 10 then .low else if x < 100 then .mid else .high
def weight (l : Level) : Int32 := match l with
  | .low => 1
  | .mid => 5
  | .high => 9
def wide (s : Shape) : Bool := match s with
  | .rect w h _ => w > h
  | _ => false
def size (s : Shape) : Int32 := match s with
  | .circle r => r
  | .rect w _ _ => w
  | .ring r _ => r
  | .dot => 0
def bigger (a b : Shape) : Shape := if size b > size a then b else a
def provenValue (p : Proven) : Int32 := match p with
  | .mk n _ => n
*/
#include "kinds.h"

LF_MODEL("refines=levelOf")
kinds_level level_of(int32_t x) {
    if (x < 10)
        return kinds_level_low;
    if (x < 100)
        return kinds_level_mid;
    return kinds_level_high;
}

LF_MODEL("refines=weight")
int32_t weight(kinds_level l) {
    switch (l) {
    case kinds_level_low:
        return 1;
    case kinds_level_mid:
        return 5;
    default:
        return 9;
    }
}

LF_MODEL("refines=wide")
bool wide(kinds_shape s) {
    if (s.tag == kinds_shape_rect)
        return s.as.rect.w > s.as.rect.h;
    return false;
}

int32_t shape_size(kinds_shape s) {
    if (s.tag == kinds_shape_circle)
        return s.as.circle.r;
    if (s.tag == kinds_shape_rect)
        return s.as.rect.w;
    if (s.tag == kinds_shape_ring)
        return s.as.ring.r;
    return 0;
}

LF_MODEL("refines=bigger")
kinds_shape bigger(kinds_shape a, kinds_shape b) {
    if (shape_size(b) > shape_size(a))
        return b;
    return a;
}

LF_MODEL("refines=provenValue")
int32_t proven_value(kinds_proven p) { return p.as.mk.n; }
