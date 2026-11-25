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

def levelAtOr (xs : Array Int32) (i : UInt32) : Level :=
  if h : i.toNat < xs.size then levelOf xs[i.toNat] else .high
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
                   grade_level *out) {
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
