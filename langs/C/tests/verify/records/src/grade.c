/* leanfran:lean grade
import LeanCLib.C

inductive Level where
  | low
  | mid
  | high

def levelOf (x : Int32) : Level :=
  if x < 10 then .low else if x < 100 then .mid else .high

def firstOr (xs : Array Int32) (d : Int32) : Int32 := xs.getD 0 d

def firstLevel (xs : Array Int32) : Level := levelOf (xs.getD 0 0)

def levelAt (xs : Array Int32) (i : UInt32) : C.Status × Option Level :=
  if h : i.toNat < xs.size then (C.Status.ok, some (levelOf xs[i.toNat]))
  else (C.Status.invalid, none)

def firstAt (xs : Array Int32) : C.Status × Option Int32 :=
  if h : 0 < xs.size then (C.Status.ok, some xs[0])
  else (C.Status.invalid, none)

def levelAtOr (xs : Array Int32) (i : UInt32) : Level :=
  if h : i.toNat < xs.size then levelOf xs[i.toNat] else .high

def posAt (xs : Array Int32) : C.Status × Option UInt8 :=
  if h : 0 < xs.size then
    (C.Status.ok, some (if (0 : Int32) < xs[0] then 1 else 0))
  else (C.Status.invalid, none)

def byteOne (_ : Array UInt8) : C.Status × Option Int32 :=
  (C.Status.ok, some 1)

def signOne (_ : Array Int32) : C.Status × Option UInt32 :=
  (C.Status.ok, some 1)

def lowLevel (_ : Array UInt32) : C.Status × Option Level :=
  (C.Status.ok, some .low)

def levelOne (_ : Array Level) : C.Status × Option Int32 :=
  (C.Status.ok, some 1)
*/
#include "grade.h"

LF_MODEL("refines=levelOf")
grade_level level_of(int32_t x) {
    if (x < 10)
        return grade_level_low;
    if (x < 100)
        return grade_level_mid;
    return grade_level_high;
}

LF_MODEL("refines=firstOr")
int32_t first_or(const int32_t *xs LF_ARRAY(n), size_t n, int32_t d) {
    if (n == 0)
        return d;
    return xs[0];
}

LF_MODEL("refines=firstLevel")
grade_level first_level(const int32_t *xs LF_ARRAY(n), size_t n) {
    return level_of(first_or(xs, n, 0));
}

LF_MODEL("refines=levelAt")
lf_status level_at(const int32_t *xs LF_ARRAY(n), size_t n, uint32_t i,
                   grade_level *restrict out) {
    if (i >= n)
        return LF_INVALID;
    *out = level_of(xs[i]);
    return LF_OK;
}

LF_MODEL("refines=levelAtOr")
grade_level level_at_or(const int32_t *xs LF_ARRAY(n), size_t n, uint32_t i) {
    grade_level l = grade_level_high;
    level_at(xs, n, i, &l);
    return l;
}

LF_MODEL("refines=firstAt")
lf_status first_at(const int32_t *restrict xs LF_ARRAY(n), size_t n,
                   int32_t *out) {
    if (n == 0)
        return LF_INVALID;
    *out = 0;
    *out = xs[0];
    return LF_OK;
}

LF_MODEL("refines=posAt")
lf_status first_pos(const int32_t *xs LF_ARRAY(n), size_t n,
                    uint8_t *restrict out) {
    if (n == 0)
        return LF_INVALID;
    *out = 0;
    if (xs[0] > 0)
        *out = 1;
    return LF_OK;
}

LF_MODEL("refines=byteOne")
lf_status byte_one(const uint8_t *restrict bs LF_ARRAY(n), size_t n,
                   int32_t *out) {
    *out = 1;
    return LF_OK;
}

LF_MODEL("refines=signOne")
lf_status sign_one(const int32_t *xs LF_ARRAY(n), size_t n,
                   uint32_t *restrict out) {
    *out = 1;
    return LF_OK;
}

LF_MODEL("refines=lowLevel")
lf_status low_level(const uint32_t *xs LF_ARRAY(n), size_t n,
                    grade_level *restrict out) {
    *out = grade_level_low;
    return LF_OK;
}

LF_MODEL("refines=levelOne")
lf_status level_one(const grade_level *restrict ls LF_ARRAY(n), size_t n,
                    int32_t *out) {
    *out = 1;
    return LF_OK;
}
