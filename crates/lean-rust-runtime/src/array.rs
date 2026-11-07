//! `Array` (arrays of objects) and scalar arrays (`ByteArray`, `FloatArray`).

use crate::nat::nat_to_usize;
use crate::object::*;
use crate::panic::{lean_internal_panic, lean_internal_panic_out_of_memory, lean_panic_fn};
use crate::string::lean_mk_ascii_string_unchecked;
use core::mem::{offset_of, size_of};
use core::ptr;

#[inline]
unsafe fn ao(o: Obj) -> *mut ArrayObject {
    o as *mut ArrayObject
}

#[inline]
unsafe fn sao(o: Obj) -> *mut SArrayObject {
    o as *mut SArrayObject
}

/* Arrays of objects */

#[inline]
pub unsafe fn lean_alloc_array(size: usize, capacity: usize) -> Obj {
    let bytes = capacity
        .checked_mul(size_of::<Obj>())
        .and_then(|b| b.checked_add(size_of::<ArrayObject>()))
        .unwrap_or_else(|| crate::panic::lean_internal_panic_overflow());
    let o = lean_alloc_object(bytes);
    lean_set_st_header(o, LEAN_ARRAY as u32, 0);
    (*ao(o)).m_size = size;
    (*ao(o)).m_capacity = capacity;
    o
}

#[inline]
pub unsafe fn lean_array_size(o: Obj) -> usize {
    debug_check_live(o, "array read");
    (*ao(o)).m_size
}

#[inline]
pub unsafe fn lean_array_capacity(o: Obj) -> usize {
    (*ao(o)).m_capacity
}

#[inline]
pub unsafe fn lean_array_byte_size(o: Obj) -> usize {
    size_of::<ArrayObject>() + size_of::<Obj>() * lean_array_capacity(o)
}

#[inline]
pub unsafe fn lean_array_set_size(o: Obj, sz: usize) {
    (*ao(o)).m_size = sz;
}

#[inline]
pub unsafe fn lean_array_get_core(o: Obj, i: usize) -> Obj {
    debug_assert!(i < lean_array_size(o));
    *lean_array_cptr(o).add(i)
}

#[inline]
pub unsafe fn lean_array_set_core(o: Obj, i: usize, v: Obj) {
    *lean_array_cptr(o).add(i) = v;
}

#[inline]
pub unsafe fn lean_array_is_marked_linear(o: Obj) -> bool {
    (*o).m_other & LEAN_LINEAR_MARK_MASK != 0
}

#[inline]
pub unsafe fn lean_mk_empty_array() -> Obj {
    lean_alloc_array(0, 0)
}

#[inline]
pub unsafe fn lean_mk_empty_array_with_capacity(capacity: Obj) -> Obj {
    if !lean_is_scalar(capacity) {
        lean_internal_panic_out_of_memory();
    }
    lean_alloc_array(0, lean_unbox(capacity))
}

#[inline]
pub unsafe fn lean_array_get_size(a: Obj) -> Obj {
    lean_box(lean_array_size(a))
}

/// `Array.size` of an owned array.
#[inline]
pub unsafe fn lean_array_sz(a: Obj) -> Obj {
    let r = lean_box(lean_array_size(a));
    lean_dec(a);
    r
}

#[inline]
pub unsafe fn lean_array_uget(a: Obj, i: usize) -> Obj {
    let r = lean_array_get_core(a, i);
    lean_inc(r);
    r
}

#[inline]
pub unsafe fn lean_array_uget_borrowed(a: Obj, i: usize) -> Obj {
    lean_array_get_core(a, i)
}

#[inline]
pub unsafe fn lean_array_fget(a: Obj, i: Obj) -> Obj {
    lean_array_uget(a, lean_unbox(i))
}

#[inline]
pub unsafe fn lean_array_fget_borrowed(a: Obj, i: Obj) -> Obj {
    lean_array_get_core(a, lean_unbox(i))
}

/// Prints the out-of-bounds panic and returns `def_val` (owned).
pub unsafe fn lean_array_get_panic(def_val: Obj) -> Obj {
    lean_panic_fn(
        def_val,
        lean_mk_ascii_string_unchecked("Error: index out of bounds"),
    )
}

/// Consumes `a` and `v`; returns `a`.
pub unsafe fn lean_array_set_panic(a: Obj, v: Obj) -> Obj {
    lean_dec(v);
    lean_panic_fn(
        a,
        lean_mk_ascii_string_unchecked("Error: index out of bounds"),
    )
}

/// `a[i]!` (`def_val`, `a`, `i` borrowed).
#[inline]
pub unsafe fn lean_array_get(def_val: Obj, a: Obj, i: Obj) -> Obj {
    if lean_is_scalar(i) {
        let idx = lean_unbox(i);
        if idx < lean_array_size(a) {
            return lean_array_uget(a, idx);
        }
    }
    lean_inc(def_val);
    lean_array_get_panic(def_val)
}

/// `a[i]!` returning a borrowed element.
#[inline]
pub unsafe fn lean_array_get_borrowed(def_val: Obj, a: Obj, i: Obj) -> Obj {
    if lean_is_scalar(i) {
        let idx = lean_unbox(i);
        if idx < lean_array_size(a) {
            return lean_array_get_core(a, idx);
        }
    }
    lean_inc(def_val);
    lean_array_get_panic(def_val)
}

/// A copy of the array `a` (consumed), with a larger capacity when `expand`.
pub unsafe fn lean_copy_expand_array(a: Obj, expand: bool) -> Obj {
    let sz = lean_array_size(a);
    let mut cap = lean_array_capacity(a);
    if expand {
        cap = (cap + 1) * 2;
    }
    let r = lean_alloc_array(sz, cap);
    (*r).m_other |= (*a).m_other & LEAN_LINEAR_MARK_MASK;
    let src = lean_array_cptr(a);
    let dst = lean_array_cptr(r);
    if lean_is_exclusive(a) {
        ptr::copy_nonoverlapping(src, dst, sz);
        lean_dealloc(a, lean_array_byte_size(a));
    } else {
        for i in 0..sz {
            let v = *src.add(i);
            lean_inc(v);
            *dst.add(i) = v;
        }
        lean_dec(a);
    }
    r
}

pub unsafe fn lean_copy_expand_array_nonlinear(a: Obj, expand: bool) -> Obj {
    lean_copy_expand_array(a, expand)
}

#[inline]
pub unsafe fn lean_ensure_exclusive_array(a: Obj) -> Obj {
    if lean_is_exclusive(a) {
        a
    } else {
        lean_copy_expand_array(a, false)
    }
}

pub unsafe fn lean_array_mark_linear(a: Obj) -> Obj {
    let r = lean_ensure_exclusive_array(a);
    (*r).m_other |= LEAN_LINEAR_MARK_MASK;
    r
}

/// Marks `dst` (owned) linear when `src` (borrowed) is.
pub unsafe fn lean_array_propagate_mark(src: Obj, dst: Obj) -> Obj {
    if !lean_array_is_marked_linear(src) {
        dst
    } else {
        lean_array_mark_linear(dst)
    }
}

#[inline]
pub unsafe fn lean_array_uset(a: Obj, i: usize, v: Obj) -> Obj {
    let r = lean_ensure_exclusive_array(a);
    let it = lean_array_cptr(r).add(i);
    lean_dec(*it);
    *it = v;
    r
}

#[inline]
pub unsafe fn lean_array_fset(a: Obj, i: Obj, v: Obj) -> Obj {
    lean_array_uset(a, lean_unbox(i), v)
}

#[inline]
pub unsafe fn lean_array_set(a: Obj, i: Obj, v: Obj) -> Obj {
    if lean_is_scalar(i) {
        let idx = lean_unbox(i);
        if idx < lean_array_size(a) {
            return lean_array_uset(a, idx, v);
        }
    }
    lean_array_set_panic(a, v)
}

pub unsafe fn lean_array_pop(a: Obj) -> Obj {
    let r = lean_ensure_exclusive_array(a);
    let sz = lean_array_size(r);
    if sz == 0 {
        return r;
    }
    (*ao(r)).m_size = sz - 1;
    lean_dec(*lean_array_cptr(r).add(sz - 1));
    r
}

#[inline]
pub unsafe fn lean_array_uswap(a: Obj, i: usize, j: usize) -> Obj {
    let r = lean_ensure_exclusive_array(a);
    let it = lean_array_cptr(r);
    ptr::swap(it.add(i), it.add(j));
    r
}

#[inline]
pub unsafe fn lean_array_fswap(a: Obj, i: Obj, j: Obj) -> Obj {
    lean_array_uswap(a, lean_unbox(i), lean_unbox(j))
}

pub unsafe fn lean_array_swap(a: Obj, i: Obj, j: Obj) -> Obj {
    if !lean_is_scalar(i) || !lean_is_scalar(j) {
        return a;
    }
    let (ui, uj) = (lean_unbox(i), lean_unbox(j));
    let sz = lean_array_size(a);
    if ui >= sz || uj >= sz {
        return a;
    }
    lean_array_uswap(a, ui, uj)
}

pub unsafe fn lean_array_push(a: Obj, v: Obj) -> Obj {
    let r = if lean_is_exclusive(a) {
        if lean_array_capacity(a) > lean_array_size(a) {
            a
        } else {
            lean_copy_expand_array(a, true)
        }
    } else {
        lean_copy_expand_array(a, lean_array_capacity(a) < 2 * lean_array_size(a) + 1)
    };
    let sz = lean_array_size(r);
    *lean_array_cptr(r).add(sz) = v;
    (*ao(r)).m_size = sz + 1;
    r
}

/// `Array.replicate n v` (both consumed).
pub unsafe fn lean_mk_array(n: Obj, v: Obj) -> Obj {
    let sz = match nat_to_usize(n) {
        Some(s) => s,
        None => lean_internal_panic_out_of_memory(),
    };
    lean_dec(n);
    let r = lean_alloc_array(sz, sz);
    let it = lean_array_cptr(r);
    for i in 0..sz {
        *it.add(i) = v;
    }
    if sz == 0 {
        lean_dec(v);
    } else if sz > 1 {
        lean_inc_n(v, sz - 1);
    }
    r
}

/// `Array.mk` / `List.toArray` (consumes the list).
pub unsafe fn lean_array_mk(lst: Obj) -> Obj {
    let mut n = 0;
    let mut o = lst;
    while !lean_is_scalar(o) {
        n += 1;
        o = lean_ctor_get(o, 1);
    }
    let r = lean_alloc_array(n, n);
    let it = lean_array_cptr(r);
    let mut o = lst;
    for i in 0..n {
        let h = lean_ctor_get(o, 0);
        lean_inc(h);
        *it.add(i) = h;
        o = lean_ctor_get(o, 1);
    }
    lean_dec(lst);
    r
}

/// `Array.toList` (consumes the array).
pub unsafe fn lean_array_to_list(a: Obj) -> Obj {
    let sz = lean_array_size(a);
    let it = lean_array_cptr(a);
    let mut r = lean_box(0);
    for i in (0..sz).rev() {
        let h = *it.add(i);
        lean_inc(h);
        let c = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(c, 0, h);
        lean_ctor_set(c, 1, r);
        r = c;
    }
    lean_dec(a);
    r
}

/* Scalar arrays */

pub unsafe fn lean_alloc_sarray(elem_size: u32, size: usize, capacity: usize) -> Obj {
    if elem_size >= LEAN_LINEAR_MARK_MASK as u32 {
        lean_internal_panic("scalar array element size is larger than 2^7");
    }
    let bytes = capacity
        .checked_mul(elem_size as usize)
        .and_then(|b| b.checked_add(size_of::<SArrayObject>()))
        .unwrap_or_else(|| crate::panic::lean_internal_panic_overflow());
    let o = lean_alloc_object(bytes);
    lean_set_st_header(o, LEAN_SCALAR_ARRAY as u32, elem_size);
    (*sao(o)).m_size = size;
    (*sao(o)).m_capacity = capacity;
    o
}

#[inline]
pub unsafe fn lean_sarray_capacity(o: Obj) -> usize {
    (*sao(o)).m_capacity
}

#[inline]
pub unsafe fn lean_sarray_byte_size(o: Obj) -> usize {
    size_of::<SArrayObject>() + lean_sarray_elem_size(o) as usize * lean_sarray_capacity(o)
}

/// Number of elements (`ByteArray.usize` and friends).
#[inline]
pub unsafe fn lean_sarray_size(o: Obj) -> usize {
    debug_check_live(o, "array read");
    (*sao(o)).m_size
}

#[inline]
pub unsafe fn lean_sarray_set_size(o: Obj, sz: usize) {
    (*sao(o)).m_size = sz;
}

#[inline]
pub unsafe fn lean_sarray_cptr(o: Obj) -> *mut u8 {
    (o as *mut u8).add(offset_of!(SArrayObject, m_data))
}

/// The bytes of a `ByteArray`.
#[inline]
pub(crate) unsafe fn sarray_bytes<'a>(o: Obj) -> &'a [u8] {
    core::slice::from_raw_parts(
        lean_sarray_cptr(o),
        lean_sarray_size(o) * lean_sarray_elem_size(o) as usize,
    )
}

pub unsafe fn lean_copy_sarray(a: Obj, cap: usize) -> Obj {
    let esz = lean_sarray_elem_size(a);
    let sz = lean_sarray_size(a);
    let r = lean_alloc_sarray(esz, sz, cap);
    (*r).m_other |= (*a).m_other & LEAN_LINEAR_MARK_MASK;
    ptr::copy_nonoverlapping(lean_sarray_cptr(a), lean_sarray_cptr(r), sz * esz as usize);
    lean_dec(a);
    r
}

pub unsafe fn lean_copy_sarray_nonlinear(a: Obj, cap: usize) -> Obj {
    lean_copy_sarray(a, cap)
}

#[inline]
pub unsafe fn lean_sarray_ensure_exclusive(a: Obj) -> Obj {
    if lean_is_exclusive(a) {
        a
    } else {
        lean_copy_sarray(a, lean_sarray_capacity(a))
    }
}

/// `a` (consumed) with room for `min_cap` elements (twice that unless `exact`).
unsafe fn sarray_ensure_capacity(a: Obj, min_cap: usize, exact: bool) -> Obj {
    let cap = lean_sarray_capacity(a);
    if min_cap <= cap {
        return a;
    }
    let esz = lean_sarray_elem_size(a);
    let sz = lean_sarray_size(a);
    let new_cap = if exact { min_cap } else { min_cap.max(2 * cap) };
    let r = lean_alloc_sarray(esz, sz, new_cap);
    (*r).m_other |= (*a).m_other & LEAN_LINEAR_MARK_MASK;
    ptr::copy_nonoverlapping(lean_sarray_cptr(a), lean_sarray_cptr(r), sz * esz as usize);
    lean_dec(a);
    r
}

pub unsafe fn lean_sarray_mark_linear(a: Obj) -> Obj {
    let r = lean_sarray_ensure_exclusive(a);
    (*r).m_other |= LEAN_LINEAR_MARK_MASK;
    r
}

pub unsafe fn lean_sarray_propagate_mark(src: Obj, dst: Obj) -> Obj {
    if (*src).m_other & LEAN_LINEAR_MARK_MASK == 0 {
        dst
    } else {
        lean_sarray_mark_linear(dst)
    }
}

#[inline]
pub unsafe fn lean_sarray_eq(a1: Obj, a2: Obj) -> bool {
    a1 == a2 || sarray_bytes(a1) == sarray_bytes(a2)
}

#[inline]
pub unsafe fn lean_sarray_dec_eq(a1: Obj, a2: Obj) -> u8 {
    lean_sarray_eq(a1, a2) as u8
}

/* ByteArray */

/// `ByteArray.mk` (consumes the array of boxed bytes).
pub unsafe fn lean_byte_array_mk(a: Obj) -> Obj {
    let sz = lean_array_size(a);
    let r = lean_alloc_sarray(1, sz, sz);
    let src = lean_array_cptr(a);
    let dst = lean_sarray_cptr(r);
    for i in 0..sz {
        *dst.add(i) = lean_unbox(*src.add(i)) as u8;
    }
    lean_dec(a);
    r
}

/// `ByteArray.data` (consumes the byte array).
pub unsafe fn lean_byte_array_data(a: Obj) -> Obj {
    let sz = lean_sarray_size(a);
    let r = lean_alloc_array(sz, sz);
    let src = lean_sarray_cptr(a);
    let dst = lean_array_cptr(r);
    for i in 0..sz {
        *dst.add(i) = lean_box(*src.add(i) as usize);
    }
    lean_dec(a);
    r
}

pub unsafe fn lean_byte_array_hash(a: Obj) -> u64 {
    crate::string::murmur_hash_64a(sarray_bytes(a), 11)
}

#[inline]
pub unsafe fn lean_mk_empty_byte_array(capacity: Obj) -> Obj {
    if !lean_is_scalar(capacity) {
        lean_internal_panic_out_of_memory();
    }
    lean_alloc_sarray(1, 0, lean_unbox(capacity))
}

#[inline]
pub unsafe fn lean_byte_array_size(a: Obj) -> Obj {
    lean_box(lean_sarray_size(a))
}

#[inline]
pub unsafe fn lean_byte_array_uget(a: Obj, i: usize) -> u8 {
    *lean_sarray_cptr(a).add(i)
}

#[inline]
pub unsafe fn lean_byte_array_get(a: Obj, i: Obj) -> u8 {
    if lean_is_scalar(i) {
        let idx = lean_unbox(i);
        if idx < lean_sarray_size(a) {
            return lean_byte_array_uget(a, idx);
        }
    }
    0
}

#[inline]
pub unsafe fn lean_byte_array_fget(a: Obj, i: Obj) -> u8 {
    lean_byte_array_uget(a, lean_unbox(i))
}

pub unsafe fn lean_byte_array_push(a: Obj, b: u8) -> Obj {
    let sz = lean_sarray_size(a);
    let r = lean_sarray_ensure_exclusive(sarray_ensure_capacity(a, sz + 1, false));
    *lean_sarray_cptr(r).add(sz) = b;
    (*sao(r)).m_size = sz + 1;
    r
}

#[inline]
pub unsafe fn lean_byte_array_uset(a: Obj, i: usize, v: u8) -> Obj {
    let r = lean_sarray_ensure_exclusive(a);
    *lean_sarray_cptr(r).add(i) = v;
    r
}

#[inline]
pub unsafe fn lean_byte_array_set(a: Obj, i: Obj, b: u8) -> Obj {
    if !lean_is_scalar(i) {
        return a;
    }
    let idx = lean_unbox(i);
    if idx >= lean_sarray_size(a) {
        a
    } else {
        lean_byte_array_uset(a, idx, b)
    }
}

#[inline]
pub unsafe fn lean_byte_array_fset(a: Obj, i: Obj, b: u8) -> Obj {
    lean_byte_array_uset(a, lean_unbox(i), b)
}

/// `ByteArray.copySlice src srcOff dest destOff len exact` (`src` borrowed, the rest owned).
pub unsafe fn lean_byte_array_copy_slice(
    src: Obj,
    o_src_off: Obj,
    dest: Obj,
    o_dest_off: Obj,
    o_len: Obj,
    exact: u8,
) -> Obj {
    let ssz = lean_sarray_size(src);
    let dsz = lean_sarray_size(dest);
    let src_off = nat_to_usize(o_src_off).unwrap_or(usize::MAX);
    let len0 = nat_to_usize(o_len).unwrap_or(usize::MAX);
    let mut dest_off = nat_to_usize(o_dest_off).unwrap_or(usize::MAX);
    lean_dec(o_src_off);
    lean_dec(o_len);
    lean_dec(o_dest_off);
    if src_off > ssz {
        return dest;
    }
    let len = len0.min(ssz - src_off);
    if dest_off > dsz {
        dest_off = dsz;
    }
    let new_dsz = dsz.max(dest_off + len);
    let r = lean_sarray_ensure_exclusive(sarray_ensure_capacity(dest, new_dsz, exact != 0));
    (*sao(r)).m_size = new_dsz;
    ptr::copy(
        lean_sarray_cptr(src).add(src_off),
        lean_sarray_cptr(r).add(dest_off),
        len,
    );
    r
}

/// `ByteArray.toUInt64LE!` style helpers are Lean code; this is `ByteArray.size` as `USize`.
#[inline]
pub unsafe fn lean_byte_array_usize(a: Obj) -> usize {
    lean_sarray_size(a)
}

/* FloatArray */

#[inline]
unsafe fn float_cptr(a: Obj) -> *mut f64 {
    lean_sarray_cptr(a) as *mut f64
}

pub unsafe fn lean_float_array_mk(a: Obj) -> Obj {
    let sz = lean_array_size(a);
    let r = lean_alloc_sarray(size_of::<f64>() as u32, sz, sz);
    let src = lean_array_cptr(a);
    for i in 0..sz {
        ptr::write_unaligned(float_cptr(r).add(i), lean_unbox_float(*src.add(i)));
    }
    lean_dec(a);
    r
}

pub unsafe fn lean_float_array_data(a: Obj) -> Obj {
    let sz = lean_sarray_size(a);
    let r = lean_alloc_array(sz, sz);
    let dst = lean_array_cptr(r);
    for i in 0..sz {
        *dst.add(i) = lean_box_float(ptr::read_unaligned(float_cptr(a).add(i)));
    }
    lean_dec(a);
    r
}

#[inline]
pub unsafe fn lean_mk_empty_float_array(capacity: Obj) -> Obj {
    if !lean_is_scalar(capacity) {
        lean_internal_panic_out_of_memory();
    }
    lean_alloc_sarray(size_of::<f64>() as u32, 0, lean_unbox(capacity))
}

#[inline]
pub unsafe fn lean_float_array_size(a: Obj) -> Obj {
    lean_box(lean_sarray_size(a))
}

#[inline]
pub unsafe fn lean_float_array_cptr(a: Obj) -> *mut f64 {
    float_cptr(a)
}

#[inline]
pub unsafe fn lean_float_array_uget(a: Obj, i: usize) -> f64 {
    ptr::read_unaligned(float_cptr(a).add(i))
}

#[inline]
pub unsafe fn lean_float_array_fget(a: Obj, i: Obj) -> f64 {
    lean_float_array_uget(a, lean_unbox(i))
}

#[inline]
pub unsafe fn lean_float_array_get(a: Obj, i: Obj) -> f64 {
    if lean_is_scalar(i) {
        let idx = lean_unbox(i);
        if idx < lean_sarray_size(a) {
            return lean_float_array_uget(a, idx);
        }
    }
    0.0
}

pub unsafe fn lean_float_array_push(a: Obj, d: f64) -> Obj {
    let sz = lean_sarray_size(a);
    let r = lean_sarray_ensure_exclusive(sarray_ensure_capacity(a, sz + 1, false));
    ptr::write_unaligned(float_cptr(r).add(sz), d);
    (*sao(r)).m_size = sz + 1;
    r
}

#[inline]
pub unsafe fn lean_float_array_uset(a: Obj, i: usize, d: f64) -> Obj {
    let r = lean_sarray_ensure_exclusive(a);
    ptr::write_unaligned(float_cptr(r).add(i), d);
    r
}

#[inline]
pub unsafe fn lean_float_array_fset(a: Obj, i: Obj, d: f64) -> Obj {
    lean_float_array_uset(a, lean_unbox(i), d)
}

#[inline]
pub unsafe fn lean_float_array_set(a: Obj, i: Obj, d: f64) -> Obj {
    if !lean_is_scalar(i) {
        return a;
    }
    let idx = lean_unbox(i);
    if idx >= lean_sarray_size(a) {
        a
    } else {
        lean_float_array_uset(a, idx, d)
    }
}
