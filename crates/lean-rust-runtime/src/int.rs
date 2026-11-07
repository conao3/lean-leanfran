//! `Int`: scalars in the range of `i32` (as in `lean.h` on 64-bit machines), `num-bigint`
//! values in mpz objects outside it.

use crate::nat::{lean_alloc_mpz, lean_mpz_value, mk_nat, nat_value};
use crate::object::*;
use crate::panic::lean_internal_panic;
use num_bigint::BigInt;
use num_traits::{Signed, ToPrimitive, Zero};

pub const LEAN_MAX_SMALL_INT: i64 = i32::MAX as i64;
pub const LEAN_MIN_SMALL_INT: i64 = i32::MIN as i64;

/// The value of an `Int`.
#[inline]
pub(crate) unsafe fn int_value(o: Obj) -> BigInt {
    if lean_is_scalar(o) {
        BigInt::from(lean_scalar_to_int64(o))
    } else {
        lean_mpz_value(o).clone()
    }
}

/// An `Int` object for `v`.
pub(crate) unsafe fn mk_int(v: BigInt) -> Obj {
    match v.to_i64() {
        Some(n) if (LEAN_MIN_SMALL_INT..=LEAN_MAX_SMALL_INT).contains(&n) => {
            lean_box(n as i32 as u32 as usize)
        }
        _ => lean_alloc_mpz(v),
    }
}

#[inline]
pub unsafe fn lean_scalar_to_int64(a: Obj) -> i64 {
    lean_unbox(a) as u32 as i32 as i64
}

#[inline]
pub unsafe fn lean_scalar_to_int(a: Obj) -> i32 {
    lean_unbox(a) as u32 as i32
}

#[inline]
pub unsafe fn lean_int_to_int(n: i32) -> Obj {
    lean_box(n as u32 as usize)
}

#[inline]
pub unsafe fn lean_int64_to_int(n: i64) -> Obj {
    if (LEAN_MIN_SMALL_INT..=LEAN_MAX_SMALL_INT).contains(&n) {
        lean_box(n as i32 as u32 as usize)
    } else {
        lean_big_int64_to_int(n)
    }
}

pub unsafe fn lean_big_int_to_int(n: i32) -> Obj {
    lean_alloc_mpz(BigInt::from(n))
}

pub unsafe fn lean_big_size_t_to_int(n: usize) -> Obj {
    lean_alloc_mpz(BigInt::from(n))
}

pub unsafe fn lean_big_int64_to_int(n: i64) -> Obj {
    lean_alloc_mpz(BigInt::from(n))
}

/// An `Int` from its decimal digits (with an optional `-`).
pub unsafe fn lean_cstr_to_int(s: &str) -> Obj {
    match s.parse::<BigInt>() {
        Ok(v) => mk_int(v),
        Err(_) => lean_internal_panic("invalid integer literal"),
    }
}

/// `Int.ofNat` (consumes `a`).
#[inline]
pub unsafe fn lean_nat_to_int(a: Obj) -> Obj {
    if lean_is_scalar(a) {
        let v = lean_unbox(a);
        if v <= LEAN_MAX_SMALL_INT as usize {
            a
        } else {
            lean_big_size_t_to_int(v)
        }
    } else {
        a
    }
}

/// `Int.negSucc` (consumes `a`).
pub unsafe fn lean_int_neg_succ_of_nat(a: Obj) -> Obj {
    let v = nat_value(a);
    lean_dec(a);
    let n: BigInt = v + 1u32;
    mk_int(-n)
}

/// `Int.toNat` of a non-negative `Int` (consumes `a`).
pub unsafe fn lean_int_to_nat(a: Obj) -> Obj {
    if lean_is_scalar(a) {
        a
    } else {
        lean_big_int_to_nat(a)
    }
}

/// Consumes `a`.
pub unsafe fn lean_big_int_to_nat(a: Obj) -> Obj {
    let v = int_value(a);
    lean_dec(a);
    mk_nat(v)
}

#[inline]
pub unsafe fn lean_nat_abs(i: Obj) -> Obj {
    mk_nat(int_value(i).abs())
}

/* Arithmetic */

macro_rules! int_binop {
    ($name:ident, $big:ident, |$x:ident, $y:ident| $small:expr, |$bx:ident, $by:ident| $bigexpr:expr) => {
        #[inline]
        pub unsafe fn $name(a1: Obj, a2: Obj) -> Obj {
            if lean_is_scalar(a1) && lean_is_scalar(a2) {
                let $x = lean_scalar_to_int64(a1);
                let $y = lean_scalar_to_int64(a2);
                $small
            } else {
                $big(a1, a2)
            }
        }

        pub unsafe fn $big(a1: Obj, a2: Obj) -> Obj {
            let $bx = int_value(a1);
            let $by = int_value(a2);
            $bigexpr
        }
    };
}

int_binop!(
    lean_int_add,
    lean_int_big_add,
    |x, y| lean_int64_to_int(x + y),
    |x, y| mk_int(x + y)
);
int_binop!(
    lean_int_sub,
    lean_int_big_sub,
    |x, y| lean_int64_to_int(x - y),
    |x, y| mk_int(x - y)
);
int_binop!(
    lean_int_mul,
    lean_int_big_mul,
    |x, y| lean_int64_to_int(x * y),
    |x, y| mk_int(x * y)
);
int_binop!(
    lean_int_div,
    lean_int_big_div,
    |x, y| if y == 0 {
        lean_box(0)
    } else {
        lean_int64_to_int(x / y)
    },
    |x, y| if y.is_zero() {
        lean_box(0)
    } else {
        mk_int(x / y)
    }
);
int_binop!(
    lean_int_mod,
    lean_int_big_mod,
    |x, y| if y == 0 {
        lean_int64_to_int(x)
    } else {
        lean_int64_to_int(x % y)
    },
    |x, y| if y.is_zero() {
        mk_int(x)
    } else {
        mk_int(x % y)
    }
);
int_binop!(
    lean_int_ediv,
    lean_int_big_ediv,
    |x, y| if y == 0 {
        lean_box(0)
    } else {
        lean_int64_to_int(ediv(x, y))
    },
    |x, y| if y.is_zero() {
        lean_box(0)
    } else {
        mk_int(big_ediv(&x, &y))
    }
);
int_binop!(
    lean_int_emod,
    lean_int_big_emod,
    |x, y| if y == 0 {
        lean_int64_to_int(x)
    } else {
        lean_int64_to_int(emod(x, y))
    },
    |x, y| if y.is_zero() {
        mk_int(x)
    } else {
        mk_int(big_emod(&x, &y))
    }
);

#[inline]
pub unsafe fn lean_int_div_exact(a1: Obj, a2: Obj) -> Obj {
    lean_int_div(a1, a2)
}

pub unsafe fn lean_int_big_div_exact(a1: Obj, a2: Obj) -> Obj {
    lean_int_big_div(a1, a2)
}

fn ediv(n: i64, d: i64) -> i64 {
    let q = n / d;
    if n % d < 0 {
        if d > 0 {
            q - 1
        } else {
            q + 1
        }
    } else {
        q
    }
}

fn emod(n: i64, d: i64) -> i64 {
    let r = n % d;
    if r < 0 {
        if d > 0 {
            r + d
        } else {
            r - d
        }
    } else {
        r
    }
}

fn big_ediv(n: &BigInt, d: &BigInt) -> BigInt {
    let q = n / d;
    if (n % d).is_negative() {
        if d.is_positive() {
            q - 1
        } else {
            q + 1
        }
    } else {
        q
    }
}

fn big_emod(n: &BigInt, d: &BigInt) -> BigInt {
    let r = n % d;
    if r.is_negative() {
        if d.is_positive() {
            r + d
        } else {
            r - d
        }
    } else {
        r
    }
}

#[inline]
pub unsafe fn lean_int_neg(a: Obj) -> Obj {
    if lean_is_scalar(a) {
        lean_int64_to_int(-lean_scalar_to_int64(a))
    } else {
        lean_int_big_neg(a)
    }
}

pub unsafe fn lean_int_big_neg(a: Obj) -> Obj {
    mk_int(-int_value(a))
}

/* Comparisons */

#[inline]
pub unsafe fn lean_int_eq(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        a1 == a2
    } else {
        lean_int_big_eq(a1, a2)
    }
}

pub unsafe fn lean_int_big_eq(a1: Obj, a2: Obj) -> bool {
    int_value(a1) == int_value(a2)
}

#[inline]
pub unsafe fn lean_int_ne(a1: Obj, a2: Obj) -> bool {
    !lean_int_eq(a1, a2)
}

#[inline]
pub unsafe fn lean_int_le(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_scalar_to_int(a1) <= lean_scalar_to_int(a2)
    } else {
        lean_int_big_le(a1, a2)
    }
}

pub unsafe fn lean_int_big_le(a1: Obj, a2: Obj) -> bool {
    int_value(a1) <= int_value(a2)
}

#[inline]
pub unsafe fn lean_int_lt(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_scalar_to_int(a1) < lean_scalar_to_int(a2)
    } else {
        lean_int_big_lt(a1, a2)
    }
}

pub unsafe fn lean_int_big_lt(a1: Obj, a2: Obj) -> bool {
    int_value(a1) < int_value(a2)
}

pub unsafe fn lean_int_big_nonneg(a: Obj) -> bool {
    !lean_mpz_value(a).is_negative()
}

#[inline]
pub unsafe fn lean_int_dec_eq(a1: Obj, a2: Obj) -> u8 {
    lean_int_eq(a1, a2) as u8
}

#[inline]
pub unsafe fn lean_int_dec_le(a1: Obj, a2: Obj) -> u8 {
    lean_int_le(a1, a2) as u8
}

#[inline]
pub unsafe fn lean_int_dec_lt(a1: Obj, a2: Obj) -> u8 {
    lean_int_lt(a1, a2) as u8
}

#[inline]
pub unsafe fn lean_int_dec_nonneg(a: Obj) -> u8 {
    if lean_is_scalar(a) {
        (lean_scalar_to_int(a) >= 0) as u8
    } else {
        lean_int_big_nonneg(a) as u8
    }
}

/* Bitwise operations on `Int` (two's complement semantics) */

pub unsafe fn lean_int_land(a1: Obj, a2: Obj) -> Obj {
    mk_int(int_value(a1) & int_value(a2))
}

pub unsafe fn lean_int_lor(a1: Obj, a2: Obj) -> Obj {
    mk_int(int_value(a1) | int_value(a2))
}

pub unsafe fn lean_int_xor(a1: Obj, a2: Obj) -> Obj {
    mk_int(int_value(a1) ^ int_value(a2))
}

pub unsafe fn lean_int_lnot(a: Obj) -> Obj {
    mk_int(!int_value(a))
}

/// `Int.shiftRight` by a `Nat` (arithmetic shift, rounding towards negative infinity).
pub unsafe fn lean_int_shift_right(a1: Obj, a2: Obj) -> Obj {
    match crate::nat::nat_to_usize(a2) {
        Some(s) => mk_int(int_value(a1) >> s),
        None => mk_int(if int_value(a1).is_negative() {
            BigInt::from(-1)
        } else {
            BigInt::zero()
        }),
    }
}
