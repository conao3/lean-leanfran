//! `Nat`: scalars up to [`LEAN_MAX_SMALL_NAT`], `num-bigint` values in mpz objects above.

use crate::object::*;
use crate::panic::lean_internal_panic;
use core::mem::size_of;
use num_bigint::BigInt;
use num_integer::Integer;
use num_traits::{ToPrimitive, Zero};

pub const LEAN_MAX_SMALL_NAT: usize = usize::MAX >> 1;

/* mpz objects */

/// Allocates an mpz object holding `v` (not normalized).
pub unsafe fn lean_alloc_mpz(v: BigInt) -> Obj {
    let o = lean_alloc_object(size_of::<MpzObject>());
    lean_set_st_header(o, LEAN_MPZ as u32, 0);
    core::ptr::write(core::ptr::addr_of_mut!((*(o as *mut MpzObject)).m_value), v);
    o
}

/// The value of an mpz object.
#[inline]
pub unsafe fn lean_mpz_value<'a>(o: Obj) -> &'a BigInt {
    debug_check_live(o, "mpz read");
    &(*(o as *mut MpzObject)).m_value
}

/// The value of a `Nat`.
#[inline]
pub(crate) unsafe fn nat_value(o: Obj) -> BigInt {
    if lean_is_scalar(o) {
        BigInt::from(lean_unbox(o))
    } else {
        lean_mpz_value(o).clone()
    }
}

/// A `Nat` object for a non-negative value.
pub(crate) unsafe fn mk_nat(v: BigInt) -> Obj {
    match v.to_usize() {
        Some(n) if n <= LEAN_MAX_SMALL_NAT => lean_box(n),
        _ => lean_alloc_mpz(v),
    }
}

/// The value of a `Nat` as a `usize`, if it fits.
#[inline]
pub(crate) unsafe fn nat_to_usize(o: Obj) -> Option<usize> {
    if lean_is_scalar(o) {
        Some(lean_unbox(o))
    } else {
        lean_mpz_value(o).to_usize()
    }
}

/* Conversions */

#[inline]
pub unsafe fn lean_usize_to_nat(n: usize) -> Obj {
    if n <= LEAN_MAX_SMALL_NAT {
        lean_box(n)
    } else {
        lean_big_usize_to_nat(n)
    }
}

#[inline]
pub unsafe fn lean_unsigned_to_nat(n: u32) -> Obj {
    lean_usize_to_nat(n as usize)
}

#[inline]
pub unsafe fn lean_uint64_to_nat(n: u64) -> Obj {
    lean_usize_to_nat(n as usize)
}

pub unsafe fn lean_big_usize_to_nat(n: usize) -> Obj {
    lean_alloc_mpz(BigInt::from(n))
}

pub unsafe fn lean_big_uint64_to_nat(n: u64) -> Obj {
    lean_alloc_mpz(BigInt::from(n))
}

/// A `Nat` from its decimal digits.
pub unsafe fn lean_cstr_to_nat(s: &str) -> Obj {
    match s.parse::<BigInt>() {
        Ok(v) => mk_nat(v),
        Err(_) => lean_internal_panic("invalid natural number literal"),
    }
}

/* Arithmetic */

#[inline]
pub unsafe fn lean_nat_succ(a: Obj) -> Obj {
    if lean_is_scalar(a) {
        lean_usize_to_nat(lean_unbox(a) + 1)
    } else {
        lean_nat_big_succ(a)
    }
}

pub unsafe fn lean_nat_big_succ(a: Obj) -> Obj {
    mk_nat(nat_value(a) + 1)
}

#[inline]
pub unsafe fn lean_nat_add(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_usize_to_nat(lean_unbox(a1) + lean_unbox(a2))
    } else {
        lean_nat_big_add(a1, a2)
    }
}

pub unsafe fn lean_nat_big_add(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1) + nat_value(a2))
}

#[inline]
pub unsafe fn lean_nat_sub(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        let (n1, n2) = (lean_unbox(a1), lean_unbox(a2));
        if n1 < n2 {
            lean_box(0)
        } else {
            lean_box(n1 - n2)
        }
    } else {
        lean_nat_big_sub(a1, a2)
    }
}

pub unsafe fn lean_nat_big_sub(a1: Obj, a2: Obj) -> Obj {
    let (v1, v2) = (nat_value(a1), nat_value(a2));
    if v1 < v2 {
        lean_box(0)
    } else {
        mk_nat(v1 - v2)
    }
}

#[inline]
pub unsafe fn lean_nat_pred(n: Obj) -> Obj {
    lean_nat_sub(n, lean_box(1))
}

#[inline]
pub unsafe fn lean_nat_mul(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        let n1 = lean_unbox(a1);
        if n1 == 0 {
            return a1;
        }
        let n2 = lean_unbox(a2);
        match n1.checked_mul(n2) {
            Some(r) if r <= LEAN_MAX_SMALL_NAT => lean_box(r),
            _ => lean_nat_overflow_mul(n1, n2),
        }
    } else {
        lean_nat_big_mul(a1, a2)
    }
}

pub unsafe fn lean_nat_overflow_mul(a1: usize, a2: usize) -> Obj {
    mk_nat(BigInt::from(a1) * BigInt::from(a2))
}

pub unsafe fn lean_nat_big_mul(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1) * nat_value(a2))
}

#[inline]
pub unsafe fn lean_nat_div(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_box(lean_unbox(a1).checked_div(lean_unbox(a2)).unwrap_or(0))
    } else {
        lean_nat_big_div(a1, a2)
    }
}

pub unsafe fn lean_nat_big_div(a1: Obj, a2: Obj) -> Obj {
    let v2 = nat_value(a2);
    if v2.is_zero() {
        lean_box(0)
    } else {
        mk_nat(nat_value(a1) / v2)
    }
}

#[inline]
pub unsafe fn lean_nat_div_exact(a1: Obj, a2: Obj) -> Obj {
    lean_nat_div(a1, a2)
}

pub unsafe fn lean_nat_big_div_exact(a1: Obj, a2: Obj) -> Obj {
    lean_nat_big_div(a1, a2)
}

#[inline]
pub unsafe fn lean_nat_mod(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        let (n1, n2) = (lean_unbox(a1), lean_unbox(a2));
        if n2 == 0 {
            lean_box(n1)
        } else {
            lean_box(n1 % n2)
        }
    } else {
        lean_nat_big_mod(a1, a2)
    }
}

pub unsafe fn lean_nat_big_mod(a1: Obj, a2: Obj) -> Obj {
    let v2 = nat_value(a2);
    if v2.is_zero() {
        lean_inc(a1);
        a1
    } else {
        mk_nat(nat_value(a1) % v2)
    }
}

/* Comparisons */

#[inline]
pub unsafe fn lean_nat_eq(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        a1 == a2
    } else {
        lean_nat_big_eq(a1, a2)
    }
}

pub unsafe fn lean_nat_big_eq(a1: Obj, a2: Obj) -> bool {
    nat_value(a1) == nat_value(a2)
}

#[inline]
pub unsafe fn lean_nat_dec_eq(a1: Obj, a2: Obj) -> u8 {
    lean_nat_eq(a1, a2) as u8
}

#[inline]
pub unsafe fn lean_nat_ne(a1: Obj, a2: Obj) -> bool {
    !lean_nat_eq(a1, a2)
}

#[inline]
pub unsafe fn lean_nat_le(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_unbox(a1) <= lean_unbox(a2)
    } else {
        lean_nat_big_le(a1, a2)
    }
}

pub unsafe fn lean_nat_big_le(a1: Obj, a2: Obj) -> bool {
    nat_value(a1) <= nat_value(a2)
}

#[inline]
pub unsafe fn lean_nat_dec_le(a1: Obj, a2: Obj) -> u8 {
    lean_nat_le(a1, a2) as u8
}

#[inline]
pub unsafe fn lean_nat_lt(a1: Obj, a2: Obj) -> bool {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_unbox(a1) < lean_unbox(a2)
    } else {
        lean_nat_big_lt(a1, a2)
    }
}

pub unsafe fn lean_nat_big_lt(a1: Obj, a2: Obj) -> bool {
    nat_value(a1) < nat_value(a2)
}

#[inline]
pub unsafe fn lean_nat_dec_lt(a1: Obj, a2: Obj) -> u8 {
    lean_nat_lt(a1, a2) as u8
}

/* Bitwise operations */

#[inline]
pub unsafe fn lean_nat_land(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_box(lean_unbox(a1) & lean_unbox(a2))
    } else {
        lean_nat_big_land(a1, a2)
    }
}

pub unsafe fn lean_nat_big_land(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1) & nat_value(a2))
}

#[inline]
pub unsafe fn lean_nat_lor(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_box(lean_unbox(a1) | lean_unbox(a2))
    } else {
        lean_nat_big_lor(a1, a2)
    }
}

pub unsafe fn lean_nat_big_lor(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1) | nat_value(a2))
}

#[inline]
pub unsafe fn lean_nat_lxor(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        lean_box(lean_unbox(a1) ^ lean_unbox(a2))
    } else {
        lean_nat_big_xor(a1, a2)
    }
}

pub unsafe fn lean_nat_big_xor(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1) ^ nat_value(a2))
}

pub unsafe fn lean_nat_shiftl(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_unbox(a1) == 0 {
        return lean_box(0);
    }
    if !lean_is_scalar(a2) || lean_unbox(a2) > u32::MAX as usize {
        lean_internal_panic("Nat.shiftl exponent is too big");
    }
    mk_nat(nat_value(a1) << lean_unbox(a2))
}

#[inline]
pub unsafe fn lean_nat_shiftr(a1: Obj, a2: Obj) -> Obj {
    if lean_is_scalar(a1) && lean_is_scalar(a2) {
        let (s1, s2) = (lean_unbox(a1), lean_unbox(a2));
        lean_box(if s2 < usize::BITS as usize {
            s1 >> s2
        } else {
            0
        })
    } else {
        lean_nat_big_shiftr(a1, a2)
    }
}

pub unsafe fn lean_nat_big_shiftr(a1: Obj, a2: Obj) -> Obj {
    if !lean_is_scalar(a2) {
        return lean_box(0);
    }
    let a = nat_value(a1);
    let s = lean_unbox(a2);
    if s > u32::MAX as usize {
        if a.bits() > s as u64 {
            lean_internal_panic("Nat.shiftr exponent is too big");
        }
        return lean_box(0);
    }
    mk_nat(a >> s)
}

/* Other operations */

pub unsafe fn lean_nat_pow(a1: Obj, a2: Obj) -> Obj {
    if !lean_is_scalar(a2) || lean_unbox(a2) > u32::MAX as usize {
        if lean_is_scalar(a1) {
            match lean_unbox(a1) {
                0 => return lean_box(0),
                1 => return lean_box(1),
                _ => {}
            }
        }
        lean_internal_panic("Nat.pow exponent is too big");
    }
    mk_nat(num_traits::pow::Pow::pow(
        nat_value(a1),
        lean_unbox(a2) as u32,
    ))
}

pub unsafe fn lean_nat_powmod(b: Obj, e: Obj, m: Obj) -> Obj {
    if lean_is_scalar(m) && lean_unbox(m) == 0 {
        return lean_nat_pow(b, e);
    }
    mk_nat(nat_value(b).modpow(&nat_value(e), &nat_value(m)))
}

pub unsafe fn lean_nat_gcd(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1).gcd(&nat_value(a2)))
}

pub unsafe fn lean_nat_lcm(a1: Obj, a2: Obj) -> Obj {
    mk_nat(nat_value(a1).lcm(&nat_value(a2)))
}

pub unsafe fn lean_nat_log2(a: Obj) -> Obj {
    if lean_is_scalar(a) {
        let n = lean_unbox(a);
        lean_box(if n < 2 {
            0
        } else {
            (usize::BITS - 1 - n.leading_zeros()) as usize
        })
    } else {
        lean_box(lean_mpz_value(a).bits() as usize - 1)
    }
}

/// Number of bytes of the little-endian representation (`Nat.toBytesLE` helpers).
pub unsafe fn lean_nat_size_in_bytes(a: Obj) -> usize {
    let v = nat_value(a);
    if v.is_zero() {
        1
    } else {
        v.bits().div_ceil(8) as usize
    }
}
