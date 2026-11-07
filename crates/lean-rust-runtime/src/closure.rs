//! Closures and their application (`lean_apply_*`, ported from `apply.cpp`).
//!
//! `m_fun` of a closure is a Rust `unsafe fn(Obj, ...) -> Obj` with `m_arity` parameters cast to
//! `*const ()`. For an arity above [`LEAN_CLOSURE_MAX_ARGS`] it is an
//! `unsafe fn(*mut Obj) -> Obj` receiving the arguments as an array, as in the C backend.

use crate::object::*;
use core::mem::{size_of, transmute};

/// Largest arity whose function takes its arguments as separate parameters.
pub const LEAN_CLOSURE_MAX_ARGS: usize = 16;

#[inline]
pub unsafe fn lean_alloc_closure(fun: *const (), arity: u32, num_fixed: u32) -> Obj {
    debug_assert!(arity > 0 && num_fixed < arity);
    let o = lean_alloc_small_object(size_of::<ClosureObject>() + size_of::<Obj>() * arity as usize);
    lean_set_st_header(o, LEAN_CLOSURE as u32, 0);
    let c = o as *mut ClosureObject;
    (*c).m_fun = fun;
    (*c).m_arity = arity as u16;
    (*c).m_num_fixed = num_fixed as u16;
    o
}

#[inline]
pub unsafe fn lean_closure_fun(o: Obj) -> *const () {
    (*(o as *mut ClosureObject)).m_fun
}

#[inline]
pub unsafe fn lean_closure_arity(o: Obj) -> u32 {
    (*(o as *mut ClosureObject)).m_arity as u32
}

#[inline]
pub unsafe fn lean_closure_num_fixed(o: Obj) -> u32 {
    (*(o as *mut ClosureObject)).m_num_fixed as u32
}

#[inline]
pub unsafe fn lean_closure_get(o: Obj, i: u32) -> Obj {
    debug_check_live(o, "closure read");
    *lean_closure_arg_cptr(o).add(i as usize)
}

#[inline]
pub unsafe fn lean_closure_set(o: Obj, i: u32, a: Obj) {
    debug_check_live(o, "closure write");
    debug_assert!(i < lean_closure_num_fixed(o));
    *lean_closure_arg_cptr(o).add(i as usize) = a;
}

type F1 = unsafe fn(Obj) -> Obj;
type F2 = unsafe fn(Obj, Obj) -> Obj;
type F3 = unsafe fn(Obj, Obj, Obj) -> Obj;
type F4 = unsafe fn(Obj, Obj, Obj, Obj) -> Obj;
type F5 = unsafe fn(Obj, Obj, Obj, Obj, Obj) -> Obj;
type F6 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F7 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F8 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F9 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F10 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F11 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F12 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F13 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F14 = unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F15 =
    unsafe fn(Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj, Obj) -> Obj;
type F16 = unsafe fn(
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
    Obj,
) -> Obj;
type FN = unsafe fn(*mut Obj) -> Obj;

/// Calls the function `f` of a closure with all its `args.len()` arguments (`curry` in
/// `apply.cpp`). The arguments are consumed.
pub unsafe fn lean_curry(f: *const (), args: &mut [Obj]) -> Obj {
    let a = &*args;
    match a.len() {
        1 => transmute::<*const (), F1>(f)(a[0]),
        2 => transmute::<*const (), F2>(f)(a[0], a[1]),
        3 => transmute::<*const (), F3>(f)(a[0], a[1], a[2]),
        4 => transmute::<*const (), F4>(f)(a[0], a[1], a[2], a[3]),
        5 => transmute::<*const (), F5>(f)(a[0], a[1], a[2], a[3], a[4]),
        6 => transmute::<*const (), F6>(f)(a[0], a[1], a[2], a[3], a[4], a[5]),
        7 => transmute::<*const (), F7>(f)(a[0], a[1], a[2], a[3], a[4], a[5], a[6]),
        8 => transmute::<*const (), F8>(f)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]),
        9 => transmute::<*const (), F9>(f)(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]),
        10 => transmute::<*const (), F10>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9],
        ),
        11 => transmute::<*const (), F11>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10],
        ),
        12 => transmute::<*const (), F12>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11],
        ),
        13 => transmute::<*const (), F13>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12],
        ),
        14 => transmute::<*const (), F14>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13],
        ),
        15 => transmute::<*const (), F15>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13],
            a[14],
        ),
        16 => transmute::<*const (), F16>(f)(
            a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13],
            a[14], a[15],
        ),
        0 => lean_internal_panic_unreachable(),
        _ => transmute::<*const (), FN>(f)(args.as_mut_ptr()),
    }
}

/// Calls the function of `f` with its fixed arguments (incremented when `inc`) followed by
/// `extra`. `f` itself is left alone.
#[inline]
unsafe fn call_fixed(f: Obj, inc: bool, extra: &[Obj]) -> Obj {
    let fixed = lean_closure_num_fixed(f) as usize;
    let total = fixed + extra.len();
    let fx = lean_closure_arg_cptr(f);
    let mut small = [lean_box(0); LEAN_CLOSURE_MAX_ARGS];
    let mut big = Vec::new();
    let buf: &mut [Obj] = if total <= LEAN_CLOSURE_MAX_ARGS {
        &mut small[..total]
    } else {
        big.resize(total, lean_box(0));
        &mut big
    };
    for (i, b) in buf.iter_mut().enumerate().take(fixed) {
        let a = *fx.add(i);
        if inc {
            lean_inc(a);
        }
        *b = a;
    }
    buf[fixed..].copy_from_slice(extra);
    lean_curry(lean_closure_fun(f), buf)
}

/// A closure with the fixed arguments of `f` followed by `args` (`fix_args` in `apply.cpp`).
unsafe fn fix_args(f: Obj, args: &[Obj]) -> Obj {
    let arity = lean_closure_arity(f);
    let fixed = lean_closure_num_fixed(f);
    let r = lean_alloc_closure(lean_closure_fun(f), arity, fixed + args.len() as u32);
    let src = lean_closure_arg_cptr(f);
    let dst = lean_closure_arg_cptr(r);
    if !lean_is_exclusive(f) {
        for i in 0..fixed as usize {
            let a = *src.add(i);
            lean_inc(a);
            *dst.add(i) = a;
        }
        lean_dec_ref(f);
    } else {
        for i in 0..fixed as usize {
            *dst.add(i) = *src.add(i);
        }
        lean_free_object(f);
    }
    for (i, a) in args.iter().enumerate() {
        *dst.add(fixed as usize + i) = *a;
    }
    r
}

/// Applies `f` (owned) to `args` (owned), as `lean_apply_n` in `apply.cpp`.
pub unsafe fn lean_apply_slice(f: Obj, args: &[Obj]) -> Obj {
    let n = args.len();
    if lean_is_scalar(f) {
        // `f` is an erased proof
        for a in args {
            lean_dec(*a);
        }
        return f;
    }
    debug_check_live(f, "application");
    let arity = lean_closure_arity(f) as usize;
    let fixed = lean_closure_num_fixed(f) as usize;
    if arity == fixed + n {
        if arity <= LEAN_CLOSURE_MAX_ARGS && lean_is_exclusive(f) {
            let r = call_fixed(f, false, args);
            lean_free_object(f);
            return r;
        }
        let r = call_fixed(f, true, args);
        lean_dec_ref(f);
        r
    } else if arity < fixed + n {
        let k = arity - fixed;
        let new_f = call_fixed(f, true, &args[..k]);
        lean_dec_ref(f);
        lean_apply_slice(new_f, &args[k..])
    } else {
        fix_args(f, args)
    }
}

/// `lean_apply_n`.
pub unsafe fn lean_apply_n(f: Obj, n: u32, args: *mut Obj) -> Obj {
    lean_apply_slice(f, core::slice::from_raw_parts(args, n as usize))
}

/// `lean_apply_m`: application to more than 16 arguments.
pub unsafe fn lean_apply_m(f: Obj, n: u32, args: *mut Obj) -> Obj {
    lean_apply_slice(f, core::slice::from_raw_parts(args, n as usize))
}

macro_rules! apply_k {
    ($name:ident, $($a:ident),+) => {
        /// Applies the closure `f` to the arguments; all of them are consumed.
        #[inline]
        pub unsafe fn $name(f: Obj, $($a: Obj),+) -> Obj {
            lean_apply_slice(f, &[$($a),+])
        }
    };
}

apply_k!(lean_apply_1, a1);
apply_k!(lean_apply_2, a1, a2);
apply_k!(lean_apply_3, a1, a2, a3);
apply_k!(lean_apply_4, a1, a2, a3, a4);
apply_k!(lean_apply_5, a1, a2, a3, a4, a5);
apply_k!(lean_apply_6, a1, a2, a3, a4, a5, a6);
apply_k!(lean_apply_7, a1, a2, a3, a4, a5, a6, a7);
apply_k!(lean_apply_8, a1, a2, a3, a4, a5, a6, a7, a8);
apply_k!(lean_apply_9, a1, a2, a3, a4, a5, a6, a7, a8, a9);
apply_k!(lean_apply_10, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
apply_k!(lean_apply_11, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
apply_k!(
    lean_apply_12,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
    a10,
    a11,
    a12
);
apply_k!(
    lean_apply_13,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
    a10,
    a11,
    a12,
    a13
);
apply_k!(
    lean_apply_14,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
    a10,
    a11,
    a12,
    a13,
    a14
);
apply_k!(
    lean_apply_15,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
    a10,
    a11,
    a12,
    a13,
    a14,
    a15
);
apply_k!(
    lean_apply_16,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    a8,
    a9,
    a10,
    a11,
    a12,
    a13,
    a14,
    a15,
    a16
);
