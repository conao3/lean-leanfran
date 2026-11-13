//! `Float` (`f64`) and `Float32` (`f32`). The transcendental functions keep the bare C names of
//! `math.h` and are computed by the `libm` crate; `sqrt` uses the exact `f64::sqrt`.

use crate::int::lean_int_to_int;
use crate::int::lean_scalar_to_int;
use crate::nat::lean_mpz_value;
use crate::object::*;
use crate::string::lean_mk_string_unchecked;
use num_traits::Signed;

/// `std::to_string` of a finite or infinite `double`: `%f` with `inf`/`-inf`.
fn c_fixed(a: f64) -> String {
    if a.is_infinite() {
        if a > 0.0 {
            "inf".to_string()
        } else {
            "-inf".to_string()
        }
    } else {
        format!("{a:.6}")
    }
}

pub unsafe fn lean_float_to_string(a: f64) -> Obj {
    let s = if a.is_nan() {
        "NaN".to_string()
    } else {
        c_fixed(a)
    };
    lean_mk_string_unchecked(&s, s.len(), s.len())
}

pub unsafe fn lean_float32_to_string(a: f32) -> Obj {
    let s = if a.is_nan() {
        "NaN".to_string()
    } else {
        c_fixed(a as f64)
    };
    lean_mk_string_unchecked(&s, s.len(), s.len())
}

macro_rules! float_common {
    ($t:ty, $bits_t:ty, $qnan:expr,
     $add:ident, $sub:ident, $mul:ident, $div:ident, $negate:ident,
     $beq:ident, $declt:ident, $decle:ident, $isnan:ident, $isfinite:ident, $isinf:ident,
     $of_bits:ident, $to_bits:ident, $scaleb:ident, $frexp:ident, $boxf:ident,
     $to_u8:ident, $to_u16:ident, $to_u32:ident, $to_u64:ident, $to_usize:ident,
     $to_i8:ident, $to_i16:ident, $to_i32:ident, $to_i64:ident, $to_isize:ident) => {
        #[inline]
        pub unsafe fn $add(a: $t, b: $t) -> $t {
            a + b
        }
        #[inline]
        pub unsafe fn $sub(a: $t, b: $t) -> $t {
            a - b
        }
        #[inline]
        pub unsafe fn $mul(a: $t, b: $t) -> $t {
            a * b
        }
        #[inline]
        pub unsafe fn $div(a: $t, b: $t) -> $t {
            a / b
        }
        #[inline]
        pub unsafe fn $negate(a: $t) -> $t {
            -a
        }
        #[inline]
        pub unsafe fn $beq(a: $t, b: $t) -> u8 {
            (a == b) as u8
        }
        #[inline]
        pub unsafe fn $declt(a: $t, b: $t) -> u8 {
            (a < b) as u8
        }
        #[inline]
        pub unsafe fn $decle(a: $t, b: $t) -> u8 {
            (a <= b) as u8
        }
        #[inline]
        pub unsafe fn $isnan(a: $t) -> u8 {
            a.is_nan() as u8
        }
        #[inline]
        pub unsafe fn $isfinite(a: $t) -> u8 {
            a.is_finite() as u8
        }
        #[inline]
        pub unsafe fn $isinf(a: $t) -> u8 {
            a.is_infinite() as u8
        }
        /// Bit pattern to float; NaNs become the quiet NaN.
        #[inline]
        pub unsafe fn $of_bits(u: $bits_t) -> $t {
            let r = <$t>::from_bits(u);
            if r.is_nan() {
                <$t>::NAN
            } else {
                r
            }
        }
        /// Float to bit pattern; NaNs give the quiet NaN pattern.
        #[inline]
        pub unsafe fn $to_bits(a: $t) -> $bits_t {
            if a.is_nan() {
                $qnan
            } else {
                a.to_bits()
            }
        }
        /// `a * 2^b` for an `Int` `b` (borrowed).
        pub unsafe fn $scaleb(a: $t, b: Obj) -> $t {
            if lean_is_scalar(b) {
                scalbn(a as f64, lean_scalar_to_int(b)) as $t
            } else if a == 0.0 || lean_mpz_value(b).is_negative() {
                0.0
            } else {
                a * <$t>::INFINITY
            }
        }
        /// `(mantissa, exponent)` with the exponent an `Int` (0 for non-finite values).
        pub unsafe fn $frexp(a: $t) -> Obj {
            let r = lean_alloc_ctor(0, 2, 0);
            let (m, e) = frexp(a as f64);
            lean_ctor_set(r, 0, $boxf(m as $t));
            lean_ctor_set(
                r,
                1,
                if a.is_finite() {
                    lean_int_to_int(e)
                } else {
                    lean_box(0)
                },
            );
            r
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
        #[inline]
        pub unsafe fn $to_i8(a: $t) -> u8 {
            a as i8 as u8
        }
        #[inline]
        pub unsafe fn $to_i16(a: $t) -> u16 {
            a as i16 as u16
        }
        #[inline]
        pub unsafe fn $to_i32(a: $t) -> u32 {
            a as i32 as u32
        }
        #[inline]
        pub unsafe fn $to_i64(a: $t) -> u64 {
            a as i64 as u64
        }
        #[inline]
        pub unsafe fn $to_isize(a: $t) -> usize {
            a as isize as usize
        }
    };
}

float_common!(
    f64,
    u64,
    0x7ff8000000000000u64,
    lean_float_add,
    lean_float_sub,
    lean_float_mul,
    lean_float_div,
    lean_float_negate,
    lean_float_beq,
    lean_float_decLt,
    lean_float_decLe,
    lean_float_isnan,
    lean_float_isfinite,
    lean_float_isinf,
    lean_float_of_bits,
    lean_float_to_bits,
    lean_float_scaleb,
    lean_float_frexp,
    lean_box_float,
    lean_float_to_uint8,
    lean_float_to_uint16,
    lean_float_to_uint32,
    lean_float_to_uint64,
    lean_float_to_usize,
    lean_float_to_int8,
    lean_float_to_int16,
    lean_float_to_int32,
    lean_float_to_int64,
    lean_float_to_isize
);
float_common!(
    f32,
    u32,
    0x7fc00000u32,
    lean_float32_add,
    lean_float32_sub,
    lean_float32_mul,
    lean_float32_div,
    lean_float32_negate,
    lean_float32_beq,
    lean_float32_decLt,
    lean_float32_decLe,
    lean_float32_isnan,
    lean_float32_isfinite,
    lean_float32_isinf,
    lean_float32_of_bits,
    lean_float32_to_bits,
    lean_float32_scaleb,
    lean_float32_frexp,
    lean_box_float32,
    lean_float32_to_uint8,
    lean_float32_to_uint16,
    lean_float32_to_uint32,
    lean_float32_to_uint64,
    lean_float32_to_usize,
    lean_float32_to_int8,
    lean_float32_to_int16,
    lean_float32_to_int32,
    lean_float32_to_int64,
    lean_float32_to_isize
);

#[inline]
pub unsafe fn lean_float_to_float32(a: f64) -> f32 {
    a as f32
}

#[inline]
pub unsafe fn lean_float32_to_float(a: f32) -> f64 {
    a as f64
}

fn scalbn(a: f64, n: i32) -> f64 {
    libm::scalbn(a, n)
}

fn frexp(a: f64) -> (f64, i32) {
    libm::frexp(a)
}

/* `math.h` */

macro_rules! libm1 {
    ($($name:ident: $t:ty),* $(,)?) => {
        $(
            #[inline]
            pub unsafe fn $name(a: $t) -> $t {
                libm::$name(a)
            }
        )*
    };
}

macro_rules! libm2 {
    ($($name:ident: $t:ty),* $(,)?) => {
        $(
            #[inline]
            pub unsafe fn $name(a: $t, b: $t) -> $t {
                libm::$name(a, b)
            }
        )*
    };
}

libm1!(
    sin: f64, cos: f64, tan: f64, asin: f64, acos: f64, atan: f64, sinh: f64, cosh: f64, tanh: f64,
    asinh: f64, acosh: f64, atanh: f64, exp: f64, exp2: f64, log: f64, log2: f64, log10: f64,
    cbrt: f64, ceil: f64, floor: f64, round: f64, fabs: f64,
    sinf: f32, cosf: f32, tanf: f32, asinf: f32, acosf: f32, atanf: f32, sinhf: f32, coshf: f32,
    tanhf: f32, asinhf: f32, acoshf: f32, atanhf: f32, expf: f32, exp2f: f32, logf: f32, log2f: f32,
    log10f: f32, cbrtf: f32, ceilf: f32, floorf: f32, roundf: f32, fabsf: f32,
);

libm2!(atan2: f64, pow: f64, atan2f: f32, powf: f32);

#[inline]
pub unsafe fn sqrt(a: f64) -> f64 {
    a.sqrt()
}

#[inline]
pub unsafe fn sqrtf(a: f32) -> f32 {
    a.sqrt()
}

#[inline]
pub unsafe fn fma(a: f64, b: f64, c: f64) -> f64 {
    a.mul_add(b, c)
}

#[inline]
pub unsafe fn fmaf(a: f32, b: f32, c: f32) -> f32 {
    a.mul_add(b, c)
}
