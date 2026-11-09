//! Rust values in the representation of Aeneas's Lean model of Rust.
//!
//! Aeneas models Rust's integers as `Std.U8` … `Std.I128` (a `BitVec` at run time, so a `Nat`
//! holding the bits), `Vec<T>` and `&[T]` as `alloc.vec.Vec` and `Slice` (a length and a
//! `ListN`), `[T; N]` as `Std.Array` (a `ListN`) and `&str` as `Str` (a `Slice U8`). [`Model`]
//! converts a Rust value to and from that representation. `#[derive(lean_rust::Model)]`
//! implements it for the structs and enums of a crate, with the constructor layout Lean gives
//! the structure or inductive type Aeneas generates.

use crate::nat::{mk_nat, nat_value};
use crate::object::*;
use num_bigint::BigInt;
use num_traits::ToPrimitive;

/// A Rust value in the representation of its type in Aeneas's model.
pub trait Model: Sized {
    /// Size of the value as a scalar field of a constructor, or 0 when it is an object field.
    const SCALAR_SIZE: u32 = 0;

    /// The owned boxed object of `self`.
    ///
    /// # Safety
    ///
    /// The result is an owned Lean object that must be released with `lean_dec` or passed on.
    unsafe fn to_model(self) -> Obj;

    /// The Rust value of the borrowed boxed object `o`.
    ///
    /// # Safety
    ///
    /// `o` must be a valid Lean value of the model type of `Self`.
    unsafe fn from_model(o: Obj) -> Self;

    /// Writes `self` as a scalar field at byte offset `off` of the constructor `o`.
    ///
    /// # Safety
    ///
    /// `o` must be a constructor with a scalar area holding the field at `off`.
    unsafe fn set_scalar(self, o: Obj, off: u32) {
        let _ = (o, off);
        unreachable!("not a scalar field")
    }

    /// Reads a scalar field at byte offset `off` of the constructor `o`.
    ///
    /// # Safety
    ///
    /// `o` must be a constructor with a scalar area holding the field at `off`.
    unsafe fn get_scalar(o: Obj, off: u32) -> Self {
        let _ = (o, off);
        unreachable!("not a scalar field")
    }
}

/// A `Nat` holding `bits`.
pub unsafe fn bits_to_model(bits: u128) -> Obj {
    match usize::try_from(bits) {
        Ok(n) => crate::nat::lean_usize_to_nat(n),
        Err(_) => mk_nat(BigInt::from(bits)),
    }
}

/// The bits held by the borrowed `Nat` `o` (below `2^128`).
pub unsafe fn bits_from_model(o: Obj) -> u128 {
    if lean_is_scalar(o) {
        lean_unbox(o) as u128
    } else {
        nat_value(o)
            .to_u128()
            .expect("a model integer has at most 128 bits")
    }
}

macro_rules! model_int {
    ($($t:ty => $u:ty),*) => {$(
        impl Model for $t {
            unsafe fn to_model(self) -> Obj {
                bits_to_model(self as $u as u128)
            }
            unsafe fn from_model(o: Obj) -> Self {
                bits_from_model(o) as $u as $t
            }
        }
    )*};
}

model_int!(
    u8 => u8, u16 => u16, u32 => u32, u64 => u64, u128 => u128, usize => usize,
    i8 => u8, i16 => u16, i32 => u32, i64 => u64, i128 => u128, isize => usize
);

impl Model for bool {
    const SCALAR_SIZE: u32 = 1;
    unsafe fn to_model(self) -> Obj {
        lean_box(self as usize)
    }
    unsafe fn from_model(o: Obj) -> Self {
        lean_unbox(o) != 0
    }
    unsafe fn set_scalar(self, o: Obj, off: u32) {
        lean_ctor_set_uint8(o, off, self as u8);
    }
    unsafe fn get_scalar(o: Obj, off: u32) -> Self {
        lean_ctor_get_uint8(o, off) != 0
    }
}

impl Model for char {
    const SCALAR_SIZE: u32 = 4;
    unsafe fn to_model(self) -> Obj {
        crate::lean_box_uint32(self as u32)
    }
    unsafe fn from_model(o: Obj) -> Self {
        crate::marshal::char_of_u32(crate::lean_unbox_uint32(o))
    }
    unsafe fn set_scalar(self, o: Obj, off: u32) {
        lean_ctor_set_uint32(o, off, self as u32);
    }
    unsafe fn get_scalar(o: Obj, off: u32) -> Self {
        crate::marshal::char_of_u32(lean_ctor_get_uint32(o, off))
    }
}

impl Model for () {
    unsafe fn to_model(self) -> Obj {
        lean_box(0)
    }
    unsafe fn from_model(_o: Obj) -> Self {}
}

/// `ListN α n` of the elements.
pub unsafe fn list_n_to_model<T>(v: Vec<T>, mut f: impl FnMut(T) -> Obj) -> Obj {
    let elems: Vec<Obj> = v.into_iter().map(&mut f).collect();
    let mut r = lean_box(0);
    for (n, e) in elems.into_iter().rev().enumerate() {
        let c = lean_alloc_ctor(1, 3, 0);
        lean_ctor_set(c, 0, crate::nat::lean_usize_to_nat(n));
        lean_ctor_set(c, 1, e);
        lean_ctor_set(c, 2, r);
        r = c;
    }
    r
}

/// The elements of the borrowed `ListN α n`.
pub unsafe fn list_n_from_model<T>(mut o: Obj, mut f: impl FnMut(Obj) -> T) -> Vec<T> {
    let mut out = Vec::new();
    while !lean_is_scalar(o) {
        out.push(f(lean_ctor_get(o, 1)));
        o = lean_ctor_get(o, 2);
    }
    out
}

/// `Slice α` (and `alloc.vec.Vec α`, a structure around it) of the elements.
pub unsafe fn slice_to_model<T>(v: Vec<T>, f: impl FnMut(T) -> Obj) -> Obj {
    let n = v.len();
    let s = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(s, 0, crate::nat::lean_usize_to_nat(n));
    lean_ctor_set(s, 1, list_n_to_model(v, f));
    s
}

/// The elements of the borrowed `Slice α`.
pub unsafe fn slice_from_model<T>(o: Obj, f: impl FnMut(Obj) -> T) -> Vec<T> {
    list_n_from_model(lean_ctor_get(o, 1), f)
}

impl<T: Model> Model for Vec<T> {
    unsafe fn to_model(self) -> Obj {
        slice_to_model(self, |x| x.to_model())
    }
    unsafe fn from_model(o: Obj) -> Self {
        slice_from_model(o, |x| T::from_model(x))
    }
}

impl<T: Model, const N: usize> Model for [T; N] {
    unsafe fn to_model(self) -> Obj {
        list_n_to_model(Vec::from(self), |x| x.to_model())
    }
    unsafe fn from_model(o: Obj) -> Self {
        array_n_from_model(o, |x| T::from_model(x))
    }
}

impl Model for String {
    unsafe fn to_model(self) -> Obj {
        self.into_bytes().to_model()
    }
    unsafe fn from_model(o: Obj) -> Self {
        String::from_utf8(Vec::<u8>::from_model(o)).expect("a Str of UTF-8")
    }
}

impl<T: Model> Model for Option<T> {
    unsafe fn to_model(self) -> Obj {
        match self {
            None => lean_box(0),
            Some(x) => {
                let c = lean_alloc_ctor(1, 1, 0);
                lean_ctor_set(c, 0, x.to_model());
                c
            }
        }
    }
    unsafe fn from_model(o: Obj) -> Self {
        if lean_is_scalar(o) {
            None
        } else {
            Some(T::from_model(lean_ctor_get(o, 0)))
        }
    }
}

impl<T: Model> Model for Box<T> {
    unsafe fn to_model(self) -> Obj {
        (*self).to_model()
    }
    unsafe fn from_model(o: Obj) -> Self {
        Box::new(T::from_model(o))
    }
}

unsafe fn pair(a: Obj, b: Obj) -> Obj {
    let c = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(c, 0, a);
    lean_ctor_set(c, 1, b);
    c
}

impl<A: Model, B: Model> Model for (A, B) {
    unsafe fn to_model(self) -> Obj {
        pair(self.0.to_model(), self.1.to_model())
    }
    unsafe fn from_model(o: Obj) -> Self {
        (
            A::from_model(lean_ctor_get(o, 0)),
            B::from_model(lean_ctor_get(o, 1)),
        )
    }
}

impl<A: Model, B: Model, C: Model> Model for (A, B, C) {
    unsafe fn to_model(self) -> Obj {
        pair(self.0.to_model(), (self.1, self.2).to_model())
    }
    unsafe fn from_model(o: Obj) -> Self {
        let (b, c) = <(B, C)>::from_model(lean_ctor_get(o, 1));
        (A::from_model(lean_ctor_get(o, 0)), b, c)
    }
}

impl<A: Model, B: Model, C: Model, D: Model> Model for (A, B, C, D) {
    unsafe fn to_model(self) -> Obj {
        pair(self.0.to_model(), (self.1, self.2, self.3).to_model())
    }
    unsafe fn from_model(o: Obj) -> Self {
        let (b, c, d) = <(B, C, D)>::from_model(lean_ctor_get(o, 1));
        (A::from_model(lean_ctor_get(o, 0)), b, c, d)
    }
}

/// The layout of a constructor whose fields have the [`Model::SCALAR_SIZE`]s `sizes`, as Lean
/// lays it out: object fields first in their order, then the scalar fields by decreasing size.
/// Per field: the object index or the byte offset in the scalar area; and the number of object
/// fields and the size of the scalar area.
pub fn ctor_layout(sizes: &[u32]) -> (Vec<u32>, u32, u32) {
    let objs = sizes.iter().filter(|&&s| s == 0).count() as u32;
    let mut slot = vec![0u32; sizes.len()];
    let mut next_obj = 0;
    for (i, &s) in sizes.iter().enumerate() {
        if s == 0 {
            slot[i] = next_obj;
            next_obj += 1;
        }
    }
    let mut off = 0;
    for size in [8, 4, 2, 1] {
        for (i, &s) in sizes.iter().enumerate() {
            if s == size {
                slot[i] = off;
                off += size;
            }
        }
    }
    (slot, objs, off)
}

/// Offset of a scalar field of a constructor with `objs` object fields.
pub const fn scalar_offset(objs: u32, off: u32) -> u32 {
    objs * core::mem::size_of::<usize>() as u32 + off
}

/// `[T; N]` of the elements of the borrowed `ListN α N` (`Std.Array α N`).
pub unsafe fn array_n_from_model<T, const N: usize>(o: Obj, f: impl FnMut(Obj) -> T) -> [T; N] {
    match list_n_from_model(o, f).try_into() {
        Ok(a) => a,
        Err(_) => unreachable!("Std.Array of a different length"),
    }
}

/// The constructors of Aeneas's `Error`, by tag.
const AENEAS_ERRORS: [&str; 7] = [
    "assertionFailure",
    "integerOverflow",
    "divisionByZero",
    "arrayOutOfBounds",
    "maximumSizeExceeded",
    "panic",
    "undef",
];

/// The value of the owned `MatchResult α` `m` (the result of `Result.match`): `ok` gives the
/// value, `fail` and `div` are a Rust panic.
pub unsafe fn result_value<T>(m: Obj, f: impl FnOnce(Obj) -> T) -> T {
    match lean_obj_tag(m) {
        0 => {
            let v = f(lean_ctor_get(m, 0));
            lean_dec(m);
            v
        }
        1 => panic!("lean-rust: the Lean function diverges"),
        _ => {
            let e = lean_ctor_get(m, 0);
            let tag = if lean_is_scalar(e) {
                lean_unbox(e)
            } else {
                lean_obj_tag(e) as usize
            };
            panic!(
                "lean-rust: the Lean function fails: {}",
                AENEAS_ERRORS.get(tag).unwrap_or(&"error")
            )
        }
    }
}
