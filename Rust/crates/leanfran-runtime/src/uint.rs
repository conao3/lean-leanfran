//! Fixed-width integers: `UInt8`..`UInt64`, `USize` and the signed `Int8`..`Int64`, `ISize`
//! (stored in the unsigned type of the same width, as in the IR).

use crate::int::{int_value, lean_int64_to_int, lean_scalar_to_int64};
use crate::nat::{lean_mpz_value, lean_usize_to_nat};
use crate::object::*;
use num_bigint::BigInt;

/// The low 64 bits of the two's complement representation of `v`.
fn big_low_u64(v: &BigInt) -> u64 {
    let (sign, digits) = v.to_u64_digits();
    let low = digits.first().copied().unwrap_or(0);
    if sign == num_bigint::Sign::Minus {
        low.wrapping_neg()
    } else {
        low
    }
}

macro_rules! uint_ops {
    ($t:ty, $bits:expr,
     $of_nat:ident, $of_nat_mk:ident, $of_big_nat:ident,
     $add:ident, $sub:ident, $mul:ident, $div:ident, $modu:ident,
     $land:ident, $lor:ident, $xor:ident, $shl:ident, $shr:ident, $compl:ident, $neg:ident, $log2:ident,
     $eq:ident, $lt:ident, $le:ident, $to_float:ident, $to_float32:ident, $of_bool:ident,
     $to_u8:ident, $to_u16:ident, $to_u32:ident, $to_u64:ident, $to_usize:ident) => {
        #[inline]
        pub unsafe fn $of_nat(a: Obj) -> $t {
            if lean_is_scalar(a) {
                lean_unbox(a) as $t
            } else {
                $of_big_nat(a)
            }
        }
        /// `UIntN.ofBitVec`: consumes `a`.
        #[inline]
        pub unsafe fn $of_nat_mk(a: Obj) -> $t {
            let r = $of_nat(a);
            lean_dec(a);
            r
        }
        pub unsafe fn $of_big_nat(a: Obj) -> $t {
            big_low_u64(lean_mpz_value(a)) as $t
        }
        #[inline]
        pub unsafe fn $add(a: $t, b: $t) -> $t {
            a.wrapping_add(b)
        }
        #[inline]
        pub unsafe fn $sub(a: $t, b: $t) -> $t {
            a.wrapping_sub(b)
        }
        #[inline]
        pub unsafe fn $mul(a: $t, b: $t) -> $t {
            a.wrapping_mul(b)
        }
        #[inline]
        pub unsafe fn $div(a: $t, b: $t) -> $t {
            if b == 0 {
                0
            } else {
                a / b
            }
        }
        #[inline]
        pub unsafe fn $modu(a: $t, b: $t) -> $t {
            if b == 0 {
                a
            } else {
                a % b
            }
        }
        #[inline]
        pub unsafe fn $land(a: $t, b: $t) -> $t {
            a & b
        }
        #[inline]
        pub unsafe fn $lor(a: $t, b: $t) -> $t {
            a | b
        }
        #[inline]
        pub unsafe fn $xor(a: $t, b: $t) -> $t {
            a ^ b
        }
        #[inline]
        pub unsafe fn $shl(a: $t, b: $t) -> $t {
            a << (b % $bits)
        }
        #[inline]
        pub unsafe fn $shr(a: $t, b: $t) -> $t {
            a >> (b % $bits)
        }
        #[inline]
        pub unsafe fn $compl(a: $t) -> $t {
            !a
        }
        #[inline]
        pub unsafe fn $neg(a: $t) -> $t {
            a.wrapping_neg()
        }
        #[inline]
        pub unsafe fn $log2(a: $t) -> $t {
            if a < 2 {
                0
            } else {
                ($bits - 1 - a.leading_zeros()) as $t
            }
        }
        #[inline]
        pub unsafe fn $eq(a: $t, b: $t) -> u8 {
            (a == b) as u8
        }
        #[inline]
        pub unsafe fn $lt(a: $t, b: $t) -> u8 {
            (a < b) as u8
        }
        #[inline]
        pub unsafe fn $le(a: $t, b: $t) -> u8 {
            (a <= b) as u8
        }
        #[inline]
        pub unsafe fn $to_float(a: $t) -> f64 {
            a as f64
        }
        #[inline]
        pub unsafe fn $to_float32(a: $t) -> f32 {
            a as f32
        }
        #[inline]
        pub unsafe fn $of_bool(a: u8) -> $t {
            a as $t
        }
        #[inline]
        pub unsafe fn $to_u8(a: $t) -> u8 {
            a as u8
        }
        #[inline]
        pub unsafe fn $to_u16(a: $t) -> u16 {
            a as u16
        }
        #[inline]
        pub unsafe fn $to_u32(a: $t) -> u32 {
            a as u32
        }
        #[inline]
        pub unsafe fn $to_u64(a: $t) -> u64 {
            a as u64
        }
        #[inline]
        pub unsafe fn $to_usize(a: $t) -> usize {
            a as usize
        }
    };
}

uint_ops!(
    u8,
    8,
    lean_uint8_of_nat,
    lean_uint8_of_nat_mk,
    lean_uint8_of_big_nat,
    lean_uint8_add,
    lean_uint8_sub,
    lean_uint8_mul,
    lean_uint8_div,
    lean_uint8_mod,
    lean_uint8_land,
    lean_uint8_lor,
    lean_uint8_xor,
    lean_uint8_shift_left,
    lean_uint8_shift_right,
    lean_uint8_complement,
    lean_uint8_neg,
    lean_uint8_log2,
    lean_uint8_dec_eq,
    lean_uint8_dec_lt,
    lean_uint8_dec_le,
    lean_uint8_to_float,
    lean_uint8_to_float32,
    lean_bool_to_uint8,
    lean_uint8_to_uint8,
    lean_uint8_to_uint16,
    lean_uint8_to_uint32,
    lean_uint8_to_uint64,
    lean_uint8_to_usize
);
uint_ops!(
    u16,
    16,
    lean_uint16_of_nat,
    lean_uint16_of_nat_mk,
    lean_uint16_of_big_nat,
    lean_uint16_add,
    lean_uint16_sub,
    lean_uint16_mul,
    lean_uint16_div,
    lean_uint16_mod,
    lean_uint16_land,
    lean_uint16_lor,
    lean_uint16_xor,
    lean_uint16_shift_left,
    lean_uint16_shift_right,
    lean_uint16_complement,
    lean_uint16_neg,
    lean_uint16_log2,
    lean_uint16_dec_eq,
    lean_uint16_dec_lt,
    lean_uint16_dec_le,
    lean_uint16_to_float,
    lean_uint16_to_float32,
    lean_bool_to_uint16,
    lean_uint16_to_uint8,
    lean_uint16_to_uint16,
    lean_uint16_to_uint32,
    lean_uint16_to_uint64,
    lean_uint16_to_usize
);
uint_ops!(
    u32,
    32,
    lean_uint32_of_nat,
    lean_uint32_of_nat_mk,
    lean_uint32_of_big_nat,
    lean_uint32_add,
    lean_uint32_sub,
    lean_uint32_mul,
    lean_uint32_div,
    lean_uint32_mod,
    lean_uint32_land,
    lean_uint32_lor,
    lean_uint32_xor,
    lean_uint32_shift_left,
    lean_uint32_shift_right,
    lean_uint32_complement,
    lean_uint32_neg,
    lean_uint32_log2,
    lean_uint32_dec_eq,
    lean_uint32_dec_lt,
    lean_uint32_dec_le,
    lean_uint32_to_float,
    lean_uint32_to_float32,
    lean_bool_to_uint32,
    lean_uint32_to_uint8,
    lean_uint32_to_uint16,
    lean_uint32_to_uint32,
    lean_uint32_to_uint64,
    lean_uint32_to_usize
);
uint_ops!(
    u64,
    64,
    lean_uint64_of_nat,
    lean_uint64_of_nat_mk,
    lean_uint64_of_big_nat,
    lean_uint64_add,
    lean_uint64_sub,
    lean_uint64_mul,
    lean_uint64_div,
    lean_uint64_mod,
    lean_uint64_land,
    lean_uint64_lor,
    lean_uint64_xor,
    lean_uint64_shift_left,
    lean_uint64_shift_right,
    lean_uint64_complement,
    lean_uint64_neg,
    lean_uint64_log2,
    lean_uint64_dec_eq,
    lean_uint64_dec_lt,
    lean_uint64_dec_le,
    lean_uint64_to_float,
    lean_uint64_to_float32,
    lean_bool_to_uint64,
    lean_uint64_to_uint8,
    lean_uint64_to_uint16,
    lean_uint64_to_uint32,
    lean_uint64_to_uint64,
    lean_uint64_to_usize
);
uint_ops!(
    usize,
    64,
    lean_usize_of_nat,
    lean_usize_of_nat_mk,
    lean_usize_of_big_nat,
    lean_usize_add,
    lean_usize_sub,
    lean_usize_mul,
    lean_usize_div,
    lean_usize_mod,
    lean_usize_land,
    lean_usize_lor,
    lean_usize_xor,
    lean_usize_shift_left,
    lean_usize_shift_right,
    lean_usize_complement,
    lean_usize_neg,
    lean_usize_log2,
    lean_usize_dec_eq,
    lean_usize_dec_lt,
    lean_usize_dec_le,
    lean_usize_to_float,
    lean_usize_to_float32,
    lean_bool_to_usize,
    lean_usize_to_uint8,
    lean_usize_to_uint16,
    lean_usize_to_uint32,
    lean_usize_to_uint64,
    lean_usize_to_usize
);

macro_rules! sint_ops {
    ($u:ty, $s:ty, $bits:expr,
     $of_int:ident, $of_nat:ident, $of_big_int:ident, $to_int:ident,
     $neg:ident, $add:ident, $sub:ident, $mul:ident, $div:ident, $modu:ident,
     $land:ident, $lor:ident, $xor:ident, $shl:ident, $shr:ident, $compl:ident, $abs:ident,
     $eq:ident, $lt:ident, $le:ident, $to_float:ident, $to_float32:ident, $of_bool:ident,
     $to_i8:ident, $to_i16:ident, $to_i32:ident, $to_i64:ident, $to_isize:ident) => {
        #[inline]
        pub unsafe fn $of_int(a: Obj) -> $u {
            if lean_is_scalar(a) {
                lean_scalar_to_int64(a) as $s as $u
            } else {
                $of_big_int(a) as $u
            }
        }
        #[inline]
        pub unsafe fn $of_nat(a: Obj) -> $u {
            if lean_is_scalar(a) {
                lean_unbox(a) as $s as $u
            } else {
                $of_big_int(a) as $u
            }
        }
        pub unsafe fn $of_big_int(a: Obj) -> $s {
            big_low_u64(&int_value(a)) as $s
        }
        #[inline]
        pub unsafe fn $to_int(a: $u) -> Obj {
            lean_int64_to_int(a as $s as i64)
        }
        #[inline]
        pub unsafe fn $neg(a: $u) -> $u {
            a.wrapping_neg()
        }
        #[inline]
        pub unsafe fn $add(a: $u, b: $u) -> $u {
            a.wrapping_add(b)
        }
        #[inline]
        pub unsafe fn $sub(a: $u, b: $u) -> $u {
            a.wrapping_sub(b)
        }
        #[inline]
        pub unsafe fn $mul(a: $u, b: $u) -> $u {
            a.wrapping_mul(b)
        }
        #[inline]
        pub unsafe fn $div(a: $u, b: $u) -> $u {
            let (l, r) = (a as $s, b as $s);
            if r == 0 {
                0
            } else {
                l.wrapping_div(r) as $u
            }
        }
        #[inline]
        pub unsafe fn $modu(a: $u, b: $u) -> $u {
            let (l, r) = (a as $s, b as $s);
            if r == 0 {
                a
            } else {
                l.wrapping_rem(r) as $u
            }
        }
        #[inline]
        pub unsafe fn $land(a: $u, b: $u) -> $u {
            a & b
        }
        #[inline]
        pub unsafe fn $lor(a: $u, b: $u) -> $u {
            a | b
        }
        #[inline]
        pub unsafe fn $xor(a: $u, b: $u) -> $u {
            a ^ b
        }
        #[inline]
        pub unsafe fn $shl(a: $u, b: $u) -> $u {
            a << ((b as $s).rem_euclid($bits) as u32)
        }
        #[inline]
        pub unsafe fn $shr(a: $u, b: $u) -> $u {
            ((a as $s) >> ((b as $s).rem_euclid($bits) as u32)) as $u
        }
        #[inline]
        pub unsafe fn $compl(a: $u) -> $u {
            !a
        }
        #[inline]
        pub unsafe fn $abs(a: $u) -> $u {
            if (a as $s) < 0 {
                a.wrapping_neg()
            } else {
                a
            }
        }
        #[inline]
        pub unsafe fn $eq(a: $u, b: $u) -> u8 {
            (a == b) as u8
        }
        #[inline]
        pub unsafe fn $lt(a: $u, b: $u) -> u8 {
            ((a as $s) < (b as $s)) as u8
        }
        #[inline]
        pub unsafe fn $le(a: $u, b: $u) -> u8 {
            ((a as $s) <= (b as $s)) as u8
        }
        #[inline]
        pub unsafe fn $to_float(a: $u) -> f64 {
            a as $s as f64
        }
        #[inline]
        pub unsafe fn $to_float32(a: $u) -> f32 {
            a as $s as f32
        }
        #[inline]
        pub unsafe fn $of_bool(a: u8) -> $u {
            a as $u
        }
        #[inline]
        pub unsafe fn $to_i8(a: $u) -> u8 {
            a as $s as i8 as u8
        }
        #[inline]
        pub unsafe fn $to_i16(a: $u) -> u16 {
            a as $s as i16 as u16
        }
        #[inline]
        pub unsafe fn $to_i32(a: $u) -> u32 {
            a as $s as i32 as u32
        }
        #[inline]
        pub unsafe fn $to_i64(a: $u) -> u64 {
            a as $s as i64 as u64
        }
        #[inline]
        pub unsafe fn $to_isize(a: $u) -> usize {
            a as $s as isize as usize
        }
    };
}

sint_ops!(
    u8,
    i8,
    8,
    lean_int8_of_int,
    lean_int8_of_nat,
    lean_int8_of_big_int,
    lean_int8_to_int,
    lean_int8_neg,
    lean_int8_add,
    lean_int8_sub,
    lean_int8_mul,
    lean_int8_div,
    lean_int8_mod,
    lean_int8_land,
    lean_int8_lor,
    lean_int8_xor,
    lean_int8_shift_left,
    lean_int8_shift_right,
    lean_int8_complement,
    lean_int8_abs,
    lean_int8_dec_eq,
    lean_int8_dec_lt,
    lean_int8_dec_le,
    lean_int8_to_float,
    lean_int8_to_float32,
    lean_bool_to_int8,
    lean_int8_to_int8,
    lean_int8_to_int16,
    lean_int8_to_int32,
    lean_int8_to_int64,
    lean_int8_to_isize
);
sint_ops!(
    u16,
    i16,
    16,
    lean_int16_of_int,
    lean_int16_of_nat,
    lean_int16_of_big_int,
    lean_int16_to_int,
    lean_int16_neg,
    lean_int16_add,
    lean_int16_sub,
    lean_int16_mul,
    lean_int16_div,
    lean_int16_mod,
    lean_int16_land,
    lean_int16_lor,
    lean_int16_xor,
    lean_int16_shift_left,
    lean_int16_shift_right,
    lean_int16_complement,
    lean_int16_abs,
    lean_int16_dec_eq,
    lean_int16_dec_lt,
    lean_int16_dec_le,
    lean_int16_to_float,
    lean_int16_to_float32,
    lean_bool_to_int16,
    lean_int16_to_int8,
    lean_int16_to_int16,
    lean_int16_to_int32,
    lean_int16_to_int64,
    lean_int16_to_isize
);
sint_ops!(
    u32,
    i32,
    32,
    lean_int32_of_int,
    lean_int32_of_nat,
    lean_int32_of_big_int,
    lean_int32_to_int,
    lean_int32_neg,
    lean_int32_add,
    lean_int32_sub,
    lean_int32_mul,
    lean_int32_div,
    lean_int32_mod,
    lean_int32_land,
    lean_int32_lor,
    lean_int32_xor,
    lean_int32_shift_left,
    lean_int32_shift_right,
    lean_int32_complement,
    lean_int32_abs,
    lean_int32_dec_eq,
    lean_int32_dec_lt,
    lean_int32_dec_le,
    lean_int32_to_float,
    lean_int32_to_float32,
    lean_bool_to_int32,
    lean_int32_to_int8,
    lean_int32_to_int16,
    lean_int32_to_int32,
    lean_int32_to_int64,
    lean_int32_to_isize
);
sint_ops!(
    u64,
    i64,
    64,
    lean_int64_of_int,
    lean_int64_of_nat,
    lean_int64_of_big_int,
    lean_int64_to_int_sint,
    lean_int64_neg,
    lean_int64_add,
    lean_int64_sub,
    lean_int64_mul,
    lean_int64_div,
    lean_int64_mod,
    lean_int64_land,
    lean_int64_lor,
    lean_int64_xor,
    lean_int64_shift_left,
    lean_int64_shift_right,
    lean_int64_complement,
    lean_int64_abs,
    lean_int64_dec_eq,
    lean_int64_dec_lt,
    lean_int64_dec_le,
    lean_int64_to_float,
    lean_int64_to_float32,
    lean_bool_to_int64,
    lean_int64_to_int8,
    lean_int64_to_int16,
    lean_int64_to_int32,
    lean_int64_to_int64,
    lean_int64_to_isize
);
sint_ops!(
    usize,
    isize,
    64,
    lean_isize_of_int,
    lean_isize_of_nat,
    lean_isize_of_big_int,
    lean_isize_to_int,
    lean_isize_neg,
    lean_isize_add,
    lean_isize_sub,
    lean_isize_mul,
    lean_isize_div,
    lean_isize_mod,
    lean_isize_land,
    lean_isize_lor,
    lean_isize_xor,
    lean_isize_shift_left,
    lean_isize_shift_right,
    lean_isize_complement,
    lean_isize_abs,
    lean_isize_dec_eq,
    lean_isize_dec_lt,
    lean_isize_dec_le,
    lean_isize_to_float,
    lean_isize_to_float32,
    lean_bool_to_isize,
    lean_isize_to_int8,
    lean_isize_to_int16,
    lean_isize_to_int32,
    lean_isize_to_int64,
    lean_isize_to_isize
);

#[inline]
pub unsafe fn lean_uint8_to_nat(a: u8) -> Obj {
    lean_box(a as usize)
}

#[inline]
pub unsafe fn lean_uint16_to_nat(a: u16) -> Obj {
    lean_box(a as usize)
}

#[inline]
pub unsafe fn lean_uint32_to_nat(a: u32) -> Obj {
    lean_usize_to_nat(a as usize)
}

/// `mixHash` of two `UInt64`.
#[inline]
pub unsafe fn lean_uint64_mix_hash(h: u64, k: u64) -> u64 {
    let m: u64 = 0xc6a4a7935bd1e995;
    let mut k = k.wrapping_mul(m);
    k ^= k >> 47;
    k ^= m;
    (h ^ k).wrapping_mul(m)
}
