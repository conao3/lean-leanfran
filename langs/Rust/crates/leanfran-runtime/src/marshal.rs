//! Conversions between Rust values and Lean objects, used by the generated public functions.
//!
//! [`ToLean`] turns a Rust value into an owned boxed object; [`FromLean`] reads a Rust value
//! from a borrowed boxed object. Containers whose Rust type does not determine the Lean type
//! (`Vec<T>` is both `List` and `Array`) are converted by the functions of this module with a
//! conversion of the elements.

use crate::array::*;
use crate::int::{int_value, mk_int};
use crate::nat::{mk_nat, nat_to_usize, nat_value};
use crate::object::*;
use crate::string::*;
use core::fmt;
use core::ops::{Add, Div, Mul, Neg, Rem, Sub};
use core::str::FromStr;
use num_bigint::{BigInt, BigUint, Sign};
use num_traits::Zero;

/// Conversion of a Rust value into a Lean object.
pub trait ToLean {
    /// The owned boxed object of `self`.
    ///
    /// # Safety
    ///
    /// The result is an owned Lean object that must be released with `lean_dec` or passed on.
    unsafe fn to_lean(self) -> Obj;
}

/// Conversion of a Lean object into a Rust value.
pub trait FromLean: Sized {
    /// The Rust value of the borrowed boxed object `o`.
    ///
    /// # Safety
    ///
    /// `o` must be a valid Lean value of the type this Rust type stands for.
    unsafe fn from_lean(o: Obj) -> Self;
}

/// A Lean `Nat`: a natural number of arbitrary precision.
///
/// The arithmetic follows Lean: subtraction truncates at zero, division by zero is zero and
/// the remainder of a division by zero is the dividend.
#[derive(Clone, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Nat(BigUint);

impl Nat {
    pub fn new(v: BigUint) -> Self {
        Nat(v)
    }

    pub fn as_biguint(&self) -> &BigUint {
        &self.0
    }

    pub fn into_biguint(self) -> BigUint {
        self.0
    }
}

/// A Lean `Int`: an integer of arbitrary precision.
#[derive(Clone, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Int(BigInt);

impl Int {
    pub fn new(v: BigInt) -> Self {
        Int(v)
    }

    pub fn as_bigint(&self) -> &BigInt {
        &self.0
    }

    pub fn into_bigint(self) -> BigInt {
        self.0
    }
}

/// The error of a conversion of a [`Nat`] or [`Int`] into a Rust integer that cannot hold it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutOfRange;

impl fmt::Display for OutOfRange {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("the number does not fit in the target type")
    }
}

impl std::error::Error for OutOfRange {}

macro_rules! nat_from {
    ($($t:ty),*) => {$(
        impl From<$t> for Nat {
            fn from(v: $t) -> Self {
                Nat(BigUint::from(v))
            }
        }
        impl TryFrom<Nat> for $t {
            type Error = OutOfRange;
            fn try_from(v: Nat) -> Result<Self, OutOfRange> {
                <$t>::try_from(&v)
            }
        }
        impl TryFrom<&Nat> for $t {
            type Error = OutOfRange;
            fn try_from(v: &Nat) -> Result<Self, OutOfRange> {
                <$t>::try_from(&v.0).map_err(|_| OutOfRange)
            }
        }
    )*};
}

nat_from!(u8, u16, u32, u64, u128, usize);

macro_rules! int_from {
    ($($t:ty),*) => {$(
        impl From<$t> for Int {
            fn from(v: $t) -> Self {
                Int(BigInt::from(v))
            }
        }
        impl TryFrom<Int> for $t {
            type Error = OutOfRange;
            fn try_from(v: Int) -> Result<Self, OutOfRange> {
                <$t>::try_from(&v)
            }
        }
        impl TryFrom<&Int> for $t {
            type Error = OutOfRange;
            fn try_from(v: &Int) -> Result<Self, OutOfRange> {
                <$t>::try_from(&v.0).map_err(|_| OutOfRange)
            }
        }
    )*};
}

int_from!(i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize);

impl From<BigUint> for Nat {
    fn from(v: BigUint) -> Self {
        Nat(v)
    }
}

impl From<BigInt> for Int {
    fn from(v: BigInt) -> Self {
        Int(v)
    }
}

impl From<Nat> for Int {
    fn from(v: Nat) -> Self {
        Int(BigInt::from(v.0))
    }
}

impl TryFrom<Int> for Nat {
    type Error = OutOfRange;
    fn try_from(v: Int) -> Result<Self, OutOfRange> {
        v.0.to_biguint().map(Nat).ok_or(OutOfRange)
    }
}

impl fmt::Display for Nat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(&self.0, f)
    }
}

impl fmt::Debug for Nat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(&self.0, f)
    }
}

impl fmt::Display for Int {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(&self.0, f)
    }
}

impl fmt::Debug for Int {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(&self.0, f)
    }
}

impl FromStr for Nat {
    type Err = num_bigint::ParseBigIntError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        s.parse().map(Nat)
    }
}

impl FromStr for Int {
    type Err = num_bigint::ParseBigIntError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        s.parse().map(Int)
    }
}

impl Add for Nat {
    type Output = Nat;
    fn add(self, rhs: Nat) -> Nat {
        Nat(self.0 + rhs.0)
    }
}

impl Sub for Nat {
    type Output = Nat;
    fn sub(self, rhs: Nat) -> Nat {
        if self.0 <= rhs.0 {
            Nat::default()
        } else {
            Nat(self.0 - rhs.0)
        }
    }
}

impl Mul for Nat {
    type Output = Nat;
    fn mul(self, rhs: Nat) -> Nat {
        Nat(self.0 * rhs.0)
    }
}

impl Div for Nat {
    type Output = Nat;
    fn div(self, rhs: Nat) -> Nat {
        if rhs.0.is_zero() {
            Nat::default()
        } else {
            Nat(self.0 / rhs.0)
        }
    }
}

impl Rem for Nat {
    type Output = Nat;
    fn rem(self, rhs: Nat) -> Nat {
        if rhs.0.is_zero() {
            self
        } else {
            Nat(self.0 % rhs.0)
        }
    }
}

impl Add for Int {
    type Output = Int;
    fn add(self, rhs: Int) -> Int {
        Int(self.0 + rhs.0)
    }
}

impl Sub for Int {
    type Output = Int;
    fn sub(self, rhs: Int) -> Int {
        Int(self.0 - rhs.0)
    }
}

impl Mul for Int {
    type Output = Int;
    fn mul(self, rhs: Int) -> Int {
        Int(self.0 * rhs.0)
    }
}

impl Neg for Int {
    type Output = Int;
    fn neg(self) -> Int {
        Int(-self.0)
    }
}

/* Leaf types */

impl ToLean for Nat {
    unsafe fn to_lean(self) -> Obj {
        mk_nat(BigInt::from_biguint(Sign::Plus, self.0))
    }
}

impl FromLean for Nat {
    unsafe fn from_lean(o: Obj) -> Self {
        Nat(nat_value(o).to_biguint().unwrap_or_default())
    }
}

impl ToLean for Int {
    unsafe fn to_lean(self) -> Obj {
        mk_int(self.0)
    }
}

impl FromLean for Int {
    unsafe fn from_lean(o: Obj) -> Self {
        Int(int_value(o))
    }
}

impl ToLean for bool {
    unsafe fn to_lean(self) -> Obj {
        lean_box(self as usize)
    }
}

impl FromLean for bool {
    unsafe fn from_lean(o: Obj) -> Self {
        lean_unbox(o) != 0
    }
}

macro_rules! small_scalar {
    ($($t:ty => $u:ty),*) => {$(
        impl ToLean for $t {
            unsafe fn to_lean(self) -> Obj {
                lean_box(self as $u as usize)
            }
        }
        impl FromLean for $t {
            unsafe fn from_lean(o: Obj) -> Self {
                lean_unbox(o) as $u as $t
            }
        }
    )*};
}

small_scalar!(u8 => u8, u16 => u16, i8 => u8, i16 => u16);

macro_rules! boxed_scalar {
    ($($t:ty => $u:ty, $box:ident, $unbox:ident);*) => {$(
        impl ToLean for $t {
            unsafe fn to_lean(self) -> Obj {
                $box(self as $u)
            }
        }
        impl FromLean for $t {
            unsafe fn from_lean(o: Obj) -> Self {
                $unbox(o) as $t
            }
        }
    )*};
}

boxed_scalar!(
    u32 => u32, lean_box_uint32, lean_unbox_uint32;
    i32 => u32, lean_box_uint32, lean_unbox_uint32;
    u64 => u64, lean_box_uint64, lean_unbox_uint64;
    i64 => u64, lean_box_uint64, lean_unbox_uint64;
    usize => usize, lean_box_usize, lean_unbox_usize;
    isize => usize, lean_box_usize, lean_unbox_usize;
    f64 => f64, lean_box_float, lean_unbox_float;
    f32 => f32, lean_box_float32, lean_unbox_float32
);

impl ToLean for char {
    unsafe fn to_lean(self) -> Obj {
        lean_box_uint32(self as u32)
    }
}

impl FromLean for char {
    unsafe fn from_lean(o: Obj) -> Self {
        char_of_u32(lean_unbox_uint32(o))
    }
}

impl ToLean for () {
    unsafe fn to_lean(self) -> Obj {
        lean_box(0)
    }
}

impl FromLean for () {
    unsafe fn from_lean(_o: Obj) -> Self {}
}

impl ToLean for &str {
    unsafe fn to_lean(self) -> Obj {
        lean_mk_string(self)
    }
}

impl ToLean for String {
    unsafe fn to_lean(self) -> Obj {
        lean_mk_string(&self)
    }
}

impl FromLean for String {
    unsafe fn from_lean(o: Obj) -> Self {
        lean_string_to_str(o).to_owned()
    }
}

/// A Lean `Char` (always a Unicode scalar value).
pub fn char_of_u32(c: u32) -> char {
    char::from_u32(c).expect("a Lean Char is a Unicode scalar value")
}

/* Containers */

/// `List α` from a `Vec`.
pub unsafe fn list_to_lean<T>(v: Vec<T>, mut f: impl FnMut(T) -> Obj) -> Obj {
    let elems: Vec<Obj> = v.into_iter().map(&mut f).collect();
    let mut r = lean_box(0);
    for e in elems.into_iter().rev() {
        let c = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(c, 0, e);
        lean_ctor_set(c, 1, r);
        r = c;
    }
    r
}

/// A `Vec` from a borrowed `List α`.
pub unsafe fn list_from_lean<T>(mut o: Obj, mut f: impl FnMut(Obj) -> T) -> Vec<T> {
    let mut out = Vec::new();
    while !lean_is_scalar(o) {
        out.push(f(lean_ctor_get(o, 0)));
        o = lean_ctor_get(o, 1);
    }
    out
}

/// `Array α` from a `Vec`.
pub unsafe fn array_to_lean<T>(v: Vec<T>, mut f: impl FnMut(T) -> Obj) -> Obj {
    let a = lean_alloc_array(0, v.len());
    for (i, x) in v.into_iter().enumerate() {
        lean_array_set_core(a, i, f(x));
        lean_array_set_size(a, i + 1);
    }
    a
}

/// A `Vec` from a borrowed `Array α`.
pub unsafe fn array_from_lean<T>(o: Obj, mut f: impl FnMut(Obj) -> T) -> Vec<T> {
    (0..lean_array_size(o))
        .map(|i| f(lean_array_get_core(o, i)))
        .collect()
}

/// `Option α`.
pub unsafe fn option_to_lean<T>(v: Option<T>, f: impl FnOnce(T) -> Obj) -> Obj {
    match v {
        None => lean_box(0),
        Some(x) => {
            let c = lean_alloc_ctor(1, 1, 0);
            lean_ctor_set(c, 0, f(x));
            c
        }
    }
}

/// An `Option` from a borrowed `Option α`.
pub unsafe fn option_from_lean<T>(o: Obj, f: impl FnOnce(Obj) -> T) -> Option<T> {
    if lean_is_scalar(o) {
        None
    } else {
        Some(f(lean_ctor_get(o, 0)))
    }
}

/// `Except ε α` (`error` is constructor 0, `ok` is 1).
pub unsafe fn except_to_lean<T, E>(
    v: Result<T, E>,
    fe: impl FnOnce(E) -> Obj,
    fa: impl FnOnce(T) -> Obj,
) -> Obj {
    let (tag, x) = match v {
        Err(e) => (0, fe(e)),
        Ok(a) => (1, fa(a)),
    };
    let c = lean_alloc_ctor(tag, 1, 0);
    lean_ctor_set(c, 0, x);
    c
}

/// A `Result` from a borrowed `Except ε α`.
pub unsafe fn except_from_lean<T, E>(
    o: Obj,
    fe: impl FnOnce(Obj) -> E,
    fa: impl FnOnce(Obj) -> T,
) -> Result<T, E> {
    if lean_obj_tag(o) == 0 {
        Err(fe(lean_ctor_get(o, 0)))
    } else {
        Ok(fa(lean_ctor_get(o, 0)))
    }
}

/// `α × β`.
pub unsafe fn prod_to_lean<A, B>(
    v: (A, B),
    fa: impl FnOnce(A) -> Obj,
    fb: impl FnOnce(B) -> Obj,
) -> Obj {
    let c = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(c, 0, fa(v.0));
    lean_ctor_set(c, 1, fb(v.1));
    c
}

/// A tuple from a borrowed `α × β`.
pub unsafe fn prod_from_lean<A, B>(
    o: Obj,
    fa: impl FnOnce(Obj) -> A,
    fb: impl FnOnce(Obj) -> B,
) -> (A, B) {
    (fa(lean_ctor_get(o, 0)), fb(lean_ctor_get(o, 1)))
}

/// `Fin n` from a `usize`; panics when `i` is not below `n`.
pub unsafe fn fin_to_lean(i: usize, n: usize) -> Obj {
    assert!(i < n, "Fin {n}: index {i} is out of range");
    crate::nat::lean_usize_to_nat(i)
}

/// The `usize` of a borrowed `Fin n`.
pub unsafe fn fin_from_lean(o: Obj) -> usize {
    nat_to_usize(o).expect("a Fin value fits in usize")
}

/* IO */

/// The `std::io::Error` of the borrowed `IO.Error` `e`, with the message `msg` (an owned
/// `String` object: `IO.Error.toString e`).
pub unsafe fn io_error_to_std(e: Obj, msg: Obj) -> std::io::Error {
    use std::io::ErrorKind;
    let text = lean_string_to_str(msg).to_owned();
    crate::object::lean_dec(msg);
    let kind = match lean_obj_tag(e) {
        0 => ErrorKind::AlreadyExists,
        2 => ErrorKind::ResourceBusy,
        4 => ErrorKind::Unsupported,
        9 => ErrorKind::TimedOut,
        10 => ErrorKind::Interrupted,
        11 => ErrorKind::NotFound,
        12 => ErrorKind::InvalidInput,
        13 => ErrorKind::PermissionDenied,
        14 => ErrorKind::OutOfMemory,
        17 => ErrorKind::UnexpectedEof,
        _ => ErrorKind::Other,
    };
    std::io::Error::new(kind, text)
}
