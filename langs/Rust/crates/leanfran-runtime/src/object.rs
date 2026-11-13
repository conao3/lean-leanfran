//! Object model of `lean.h`: object layouts, allocation, reference counting, boxing and
//! constructor objects.
//!
//! The layouts are the ones of `lean.h` on a 64-bit machine. Reference counting is
//! single-threaded: `m_rc > 0` is the count, `m_rc == 0` marks a persistent object (inc/dec are
//! no-ops), and negative counts are never created. With `debug_assertions` a freed object has
//! its count set to [`FREED_RC`] and its memory is kept for a while, so that a later
//! increment, decrement or field access of it panics.

use core::ffi::c_void;
use core::mem::{offset_of, size_of};
use core::ptr;
use num_bigint::BigInt;
use std::alloc::{self, Layout};
use std::cell::Cell;

/// Header of every heap object (`lean_object`).
#[repr(C)]
pub struct Object {
    pub m_rc: i32,
    pub m_cs_sz: u16,
    pub m_other: u8,
    pub m_tag: u8,
}

/// A Lean value: a pointer to a heap object, or a scalar `(n << 1) | 1`.
pub type Obj = *mut Object;

pub const LEAN_MAX_CTOR_TAG: u8 = 244;
pub const LEAN_PROMISE: u8 = 244;
pub const LEAN_CLOSURE: u8 = 245;
pub const LEAN_ARRAY: u8 = 246;
pub const LEAN_STRUCT_ARRAY: u8 = 247;
pub const LEAN_SCALAR_ARRAY: u8 = 248;
pub const LEAN_STRING: u8 = 249;
pub const LEAN_MPZ: u8 = 250;
pub const LEAN_THUNK: u8 = 251;
pub const LEAN_TASK: u8 = 252;
pub const LEAN_REF: u8 = 253;
pub const LEAN_EXTERNAL: u8 = 254;
pub const LEAN_RESERVED: u8 = 255;

/// Linearity marker bit in `m_other` of arrays, scalar arrays and strings.
pub const LEAN_LINEAR_MARK_MASK: u8 = 0x80;

/// Reference count written into a freed object when `debug_assertions` are enabled.
pub const FREED_RC: i32 = -0x5EAD_DEAD;

#[repr(C)]
pub struct CtorObject {
    pub m_header: Object,
    pub m_objs: [Obj; 0],
}

#[repr(C)]
pub struct ArrayObject {
    pub m_header: Object,
    pub m_size: usize,
    pub m_capacity: usize,
    pub m_data: [Obj; 0],
}

#[repr(C)]
pub struct SArrayObject {
    pub m_header: Object,
    pub m_size: usize,
    pub m_capacity: usize,
    pub m_data: [u8; 0],
}

#[repr(C)]
pub struct StringObject {
    pub m_header: Object,
    /// Byte length including the `'\0'` terminator.
    pub m_size: usize,
    pub m_capacity: usize,
    /// Number of code points.
    pub m_length: usize,
    pub m_data: [u8; 0],
}

#[repr(C)]
pub struct ClosureObject {
    pub m_header: Object,
    pub m_fun: *const (),
    pub m_arity: u16,
    pub m_num_fixed: u16,
    pub m_objs: [Obj; 0],
}

#[repr(C)]
pub struct RefObject {
    pub m_header: Object,
    pub m_value: Obj,
}

#[repr(C)]
pub struct ThunkObject {
    pub m_header: Object,
    pub m_value: Obj,
    pub m_closure: Obj,
}

/// Tasks run synchronously when they are created, so `m_imp` is always null and `m_value` is
/// set.
#[repr(C)]
pub struct TaskObject {
    pub m_header: Object,
    pub m_value: Obj,
    pub m_imp: *mut c_void,
}

/// `lean_external_class`.
#[repr(C)]
pub struct ExternalClass {
    pub m_finalize: unsafe fn(*mut c_void),
    pub m_foreach: unsafe fn(*mut c_void, Obj),
}

#[repr(C)]
pub struct ExternalObject {
    pub m_header: Object,
    pub m_class: *const ExternalClass,
    pub m_data: *mut c_void,
}

/// A big natural number or integer (`mpz_object`), holding a `num-bigint` value.
#[repr(C)]
pub struct MpzObject {
    pub m_header: Object,
    pub m_value: BigInt,
}

const CTOR_OBJS: usize = offset_of!(CtorObject, m_objs);

/* Allocation */

#[inline]
fn layout_of(sz: usize) -> Layout {
    match Layout::from_size_align((sz + 7) & !7, 8) {
        Ok(l) => l,
        Err(_) => lean_internal_panic_out_of_memory(),
    }
}

/// Allocates `sz` bytes for an object (`lean_alloc_object`). The header is not initialized.
#[inline]
pub unsafe fn lean_alloc_object(sz: usize) -> Obj {
    let layout = layout_of(sz);
    let p = alloc::alloc(layout);
    if p.is_null() {
        alloc::handle_alloc_error(layout);
    }
    p as Obj
}

#[inline]
pub unsafe fn lean_alloc_small_object(sz: usize) -> Obj {
    lean_alloc_object(sz)
}

/// `lean_set_st_header`: single-threaded header with RC 1.
#[inline]
pub unsafe fn lean_set_st_header(o: Obj, tag: u32, other: u32) {
    (*o).m_rc = 1;
    (*o).m_tag = tag as u8;
    (*o).m_other = other as u8;
    (*o).m_cs_sz = 0;
}

/// `lean_set_non_heap_header`: persistent header (RC 0).
#[inline]
pub unsafe fn lean_set_non_heap_header(o: Obj, sz: usize, tag: u32, other: u32) {
    (*o).m_rc = 0;
    (*o).m_tag = tag as u8;
    (*o).m_other = other as u8;
    (*o).m_cs_sz = sz as u16;
}

/// Size in bytes of the memory block of an object (`lean_object_byte_size`).
pub unsafe fn lean_object_byte_size(o: Obj) -> usize {
    let tag = (*o).m_tag;
    if tag <= LEAN_MAX_CTOR_TAG {
        return (*o).m_cs_sz as usize;
    }
    match tag {
        LEAN_CLOSURE => {
            size_of::<ClosureObject>()
                + size_of::<Obj>() * (*(o as *mut ClosureObject)).m_arity as usize
        }
        LEAN_ARRAY => {
            size_of::<ArrayObject>() + size_of::<Obj>() * (*(o as *mut ArrayObject)).m_capacity
        }
        LEAN_SCALAR_ARRAY => {
            size_of::<SArrayObject>()
                + lean_sarray_elem_size(o) as usize * (*(o as *mut SArrayObject)).m_capacity
        }
        LEAN_STRING => size_of::<StringObject>() + (*(o as *mut StringObject)).m_capacity,
        LEAN_MPZ => size_of::<MpzObject>(),
        LEAN_THUNK => size_of::<ThunkObject>(),
        LEAN_TASK => size_of::<TaskObject>(),
        LEAN_REF => size_of::<RefObject>(),
        LEAN_EXTERNAL => size_of::<ExternalObject>(),
        _ => lean_internal_panic_unreachable(),
    }
}

/// Number of freed objects whose memory is kept to detect use after free.
#[cfg(all(debug_assertions, not(miri)))]
const QUARANTINE: usize = 1 << 14;

#[cfg(all(debug_assertions, not(miri)))]
thread_local! {
    static FREED: core::cell::RefCell<std::collections::VecDeque<(*mut u8, Layout)>> =
        const { core::cell::RefCell::new(std::collections::VecDeque::new()) };
}

/// Returns the memory block of an object of `sz` bytes to the allocator.
#[inline]
pub unsafe fn lean_dealloc(o: Obj, sz: usize) {
    let layout = layout_of(sz);
    #[cfg(debug_assertions)]
    {
        (*o).m_rc = FREED_RC;
    }
    #[cfg(all(debug_assertions, not(miri)))]
    {
        let evicted = FREED.with(|q| {
            let mut q = q.borrow_mut();
            q.push_back((o as *mut u8, layout));
            if q.len() > QUARANTINE {
                q.pop_front()
            } else {
                None
            }
        });
        if let Some((p, l)) = evicted {
            alloc::dealloc(p, l);
        }
    }
    #[cfg(not(all(debug_assertions, not(miri))))]
    alloc::dealloc(o as *mut u8, layout);
}

/// Frees the memory of an object without touching its fields (`lean_free_object`).
pub unsafe fn lean_free_object(o: Obj) {
    debug_check_live(o, "free");
    if (*o).m_tag == LEAN_MPZ {
        ptr::drop_in_place(ptr::addr_of_mut!((*(o as *mut MpzObject)).m_value));
    }
    lean_dealloc(o, lean_object_byte_size(o));
}

#[inline]
pub unsafe fn lean_free_small_object(o: Obj) {
    lean_free_object(o);
}

/* Scalars */

#[inline]
pub fn lean_is_scalar(o: Obj) -> bool {
    o.addr() & 1 == 1
}

#[inline]
pub fn lean_box(n: usize) -> Obj {
    ptr::without_provenance_mut((n << 1) | 1)
}

#[inline]
pub fn lean_unbox(o: Obj) -> usize {
    o.addr() >> 1
}

/* Reference counting */

#[cold]
#[inline(never)]
fn rc_error(o: Obj, rc: i32, op: &str) -> ! {
    if rc == FREED_RC {
        panic!("leanfran-runtime: {op} of the freed object {o:p}");
    }
    panic!("leanfran-runtime: {op} of the object {o:p} with the reference count {rc}");
}

/// Panics (with `debug_assertions`) if `o` is a freed object.
#[inline(always)]
pub unsafe fn debug_check_live(o: Obj, op: &str) {
    #[cfg(debug_assertions)]
    if !lean_is_scalar(o) && (*o).m_rc < 0 {
        rc_error(o, (*o).m_rc, op);
    }
    let _ = (o, op);
}

#[inline]
pub unsafe fn lean_is_st(o: Obj) -> bool {
    (*o).m_rc > 0
}

#[inline]
pub unsafe fn lean_is_persistent(o: Obj) -> bool {
    (*o).m_rc == 0
}

#[inline]
pub unsafe fn lean_has_rc(o: Obj) -> bool {
    (*o).m_rc != 0
}

#[inline]
pub unsafe fn lean_inc_ref_n(o: Obj, n: usize) {
    let rc = (*o).m_rc;
    if rc > 0 {
        match rc.checked_add(n as i32) {
            Some(r) if n <= i32::MAX as usize => (*o).m_rc = r,
            _ => lean_internal_panic_rc_overflow(),
        }
    } else if rc != 0 {
        rc_error(o, rc, "increment");
    }
}

#[inline]
pub unsafe fn lean_inc_ref(o: Obj) {
    let rc = (*o).m_rc;
    if rc > 0 {
        #[cfg(debug_assertions)]
        if rc == i32::MAX {
            lean_internal_panic_rc_overflow();
        }
        (*o).m_rc = rc + 1;
    } else if rc != 0 {
        rc_error(o, rc, "increment");
    }
}

#[inline]
pub unsafe fn lean_inc(o: Obj) {
    if !lean_is_scalar(o) {
        lean_inc_ref(o);
    }
}

#[inline]
pub unsafe fn lean_inc_n(o: Obj, n: usize) {
    if !lean_is_scalar(o) {
        lean_inc_ref_n(o, n);
    }
}

#[inline]
pub unsafe fn lean_dec_ref(o: Obj) {
    let rc = (*o).m_rc;
    if rc > 1 {
        (*o).m_rc = rc - 1;
    } else if rc == 1 {
        lean_dec_ref_cold(o);
    } else if rc != 0 {
        rc_error(o, rc, "decrement");
    }
}

#[inline]
pub unsafe fn lean_dec(o: Obj) {
    if !lean_is_scalar(o) {
        lean_dec_ref(o);
    }
}

thread_local! {
    static DEL_TODO: Cell<Vec<Obj>> = const { Cell::new(Vec::new()) };
}

/// Pushes the children of `o` with a single-threaded count to `todo`.
unsafe fn for_each_child(o: Obj, f: &mut impl FnMut(Obj)) {
    let tag = (*o).m_tag;
    if tag <= LEAN_MAX_CTOR_TAG {
        let objs = lean_ctor_obj_cptr(o);
        for i in 0..lean_ctor_num_objs(o) as usize {
            f(*objs.add(i));
        }
        return;
    }
    match tag {
        LEAN_CLOSURE => {
            let c = o as *mut ClosureObject;
            let objs = lean_closure_arg_cptr(o);
            for i in 0..(*c).m_num_fixed as usize {
                f(*objs.add(i));
            }
        }
        LEAN_ARRAY => {
            let data = lean_array_cptr(o);
            for i in 0..(*(o as *mut ArrayObject)).m_size {
                f(*data.add(i));
            }
        }
        LEAN_THUNK => {
            let t = o as *mut ThunkObject;
            if !(*t).m_value.is_null() {
                f((*t).m_value);
            }
            if !(*t).m_closure.is_null() {
                f((*t).m_closure);
            }
        }
        LEAN_TASK => {
            let t = o as *mut TaskObject;
            if !(*t).m_value.is_null() {
                f((*t).m_value);
            }
        }
        LEAN_REF => {
            let r = o as *mut RefObject;
            if !(*r).m_value.is_null() {
                f((*r).m_value);
            }
        }
        _ => {}
    }
}

/// Frees `o` (whose count dropped to zero) and every object only reachable from it, with an
/// explicit work list instead of recursion (`lean_del`).
#[cold]
#[inline(never)]
pub unsafe fn lean_dec_ref_cold(o: Obj) {
    let mut todo = DEL_TODO.take();
    todo.push(o);
    while let Some(o) = todo.pop() {
        let mut child = |c: Obj| {
            if lean_is_scalar(c) {
                return;
            }
            let rc = (*c).m_rc;
            if rc > 1 {
                (*c).m_rc = rc - 1;
            } else if rc == 1 {
                (*c).m_rc = 0;
                todo.push(c);
            } else if rc != 0 {
                rc_error(c, rc, "decrement");
            }
        };
        for_each_child(o, &mut child);
        if (*o).m_tag == LEAN_EXTERNAL {
            let e = o as *mut ExternalObject;
            ((*(*e).m_class).m_finalize)((*e).m_data);
        }
        lean_free_object_unchecked(o);
    }
    DEL_TODO.set(todo);
}

unsafe fn lean_free_object_unchecked(o: Obj) {
    if (*o).m_tag == LEAN_MPZ {
        ptr::drop_in_place(ptr::addr_of_mut!((*(o as *mut MpzObject)).m_value));
    }
    lean_dealloc(o, lean_object_byte_size(o));
}

/// Marks `o` and every object reachable from it as persistent (RC 0).
pub unsafe fn lean_mark_persistent(o: Obj) {
    let mut todo = vec![o];
    while let Some(o) = todo.pop() {
        if lean_is_scalar(o) || !lean_has_rc(o) {
            continue;
        }
        debug_check_live(o, "mark_persistent");
        (*o).m_rc = 0;
        if (*o).m_tag == LEAN_EXTERNAL {
            let e = o as *mut ExternalObject;
            let f = crate::closure::lean_alloc_closure(mark_persistent_fn as *const (), 1, 0);
            ((*(*e).m_class).m_foreach)((*e).m_data, f);
            lean_dec(f);
        } else {
            for_each_child(o, &mut |c| todo.push(c));
        }
    }
}

unsafe fn mark_persistent_fn(o: Obj) -> Obj {
    lean_mark_persistent(o);
    lean_box(0)
}

#[inline]
pub unsafe fn lean_mark_mt(_o: Obj) {}

/* Tags */

#[inline]
pub unsafe fn lean_ptr_tag(o: Obj) -> u8 {
    debug_check_live(o, "tag read");
    (*o).m_tag
}

#[inline]
pub unsafe fn lean_ptr_other(o: Obj) -> u32 {
    (*o).m_other as u32
}

#[inline]
pub unsafe fn lean_obj_tag(o: Obj) -> u32 {
    if lean_is_scalar(o) {
        lean_unbox(o) as u32
    } else {
        lean_ptr_tag(o) as u32
    }
}

#[inline]
pub unsafe fn lean_is_exclusive(o: Obj) -> bool {
    if lean_is_scalar(o) {
        return false;
    }
    debug_check_live(o, "exclusivity check");
    (*o).m_rc == 1
}

#[inline]
pub unsafe fn lean_is_exclusive_obj(o: Obj) -> u8 {
    lean_is_exclusive(o) as u8
}

#[inline]
pub unsafe fn lean_is_shared(o: Obj) -> bool {
    !lean_is_scalar(o) && (*o).m_rc > 1
}

#[inline]
pub unsafe fn lean_nonzero_rc(o: Obj) -> bool {
    (*o).m_rc != 0
}

#[inline]
pub fn lean_ptr_addr(o: Obj) -> usize {
    o.addr()
}

#[inline]
pub unsafe fn lean_is_ctor(o: Obj) -> bool {
    lean_ptr_tag(o) <= LEAN_MAX_CTOR_TAG
}
#[inline]
pub unsafe fn lean_is_closure(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_CLOSURE
}
#[inline]
pub unsafe fn lean_is_array(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_ARRAY
}
#[inline]
pub unsafe fn lean_is_sarray(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_SCALAR_ARRAY
}
#[inline]
pub unsafe fn lean_is_string(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_STRING
}
#[inline]
pub unsafe fn lean_is_mpz(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_MPZ
}
#[inline]
pub unsafe fn lean_is_thunk(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_THUNK
}
#[inline]
pub unsafe fn lean_is_task(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_TASK
}
#[inline]
pub unsafe fn lean_is_external(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_EXTERNAL
}
#[inline]
pub unsafe fn lean_is_ref(o: Obj) -> bool {
    lean_ptr_tag(o) == LEAN_REF
}

/* Constructor objects */

#[inline]
pub unsafe fn lean_ctor_num_objs(o: Obj) -> u32 {
    (*o).m_other as u32
}

#[inline]
pub unsafe fn lean_ctor_obj_cptr(o: Obj) -> *mut Obj {
    (o as *mut u8).add(CTOR_OBJS) as *mut Obj
}

#[inline]
pub unsafe fn lean_ctor_scalar_cptr(o: Obj) -> *mut u8 {
    lean_ctor_obj_cptr(o).add(lean_ctor_num_objs(o) as usize) as *mut u8
}

/// Allocates a constructor object; the object fields are left for `lean_ctor_set`, the scalar
/// area is zeroed.
#[inline]
pub unsafe fn lean_alloc_ctor(tag: u32, num_objs: u32, scalar_sz: u32) -> Obj {
    debug_assert!(tag <= LEAN_MAX_CTOR_TAG as u32 && num_objs < 256);
    let objs_end = CTOR_OBJS + size_of::<Obj>() * num_objs as usize;
    let sz = (objs_end + scalar_sz as usize + 7) & !7;
    if sz > u16::MAX as usize {
        lean_internal_panic("constructor object is too big");
    }
    let o = lean_alloc_object(sz);
    lean_set_st_header(o, tag, num_objs);
    (*o).m_cs_sz = sz as u16;
    ptr::write_bytes((o as *mut u8).add(objs_end), 0, sz - objs_end);
    o
}

#[inline]
pub unsafe fn lean_ctor_get(o: Obj, i: u32) -> Obj {
    debug_check_live(o, "field read");
    debug_assert!(i < lean_ctor_num_objs(o));
    *lean_ctor_obj_cptr(o).add(i as usize)
}

#[inline]
pub unsafe fn lean_ctor_set(o: Obj, i: u32, v: Obj) {
    debug_check_live(o, "field write");
    debug_assert!(i < lean_ctor_num_objs(o));
    *lean_ctor_obj_cptr(o).add(i as usize) = v;
}

#[inline]
pub unsafe fn lean_ctor_set_tag(o: Obj, new_tag: u32) {
    debug_check_live(o, "tag write");
    (*o).m_tag = new_tag as u8;
}

#[inline]
pub unsafe fn lean_ctor_release(o: Obj, i: u32) {
    let objs = lean_ctor_obj_cptr(o);
    lean_dec(*objs.add(i as usize));
    *objs.add(i as usize) = lean_box(0);
}

#[inline]
pub unsafe fn lean_ctor_get_usize(o: Obj, i: u32) -> usize {
    debug_check_live(o, "field read");
    ptr::read_unaligned(lean_ctor_obj_cptr(o).add(i as usize) as *const usize)
}

#[inline]
pub unsafe fn lean_ctor_set_usize(o: Obj, i: u32, v: usize) {
    debug_check_live(o, "field write");
    ptr::write_unaligned(lean_ctor_obj_cptr(o).add(i as usize) as *mut usize, v)
}

macro_rules! ctor_scalar {
    ($get:ident, $set:ident, $t:ty) => {
        /// Reads a scalar field at `offset` bytes from the start of the object fields.
        #[inline]
        pub unsafe fn $get(o: Obj, offset: u32) -> $t {
            debug_check_live(o, "field read");
            ptr::read_unaligned(
                (lean_ctor_obj_cptr(o) as *const u8).add(offset as usize) as *const $t
            )
        }
        /// Writes a scalar field at `offset` bytes from the start of the object fields.
        #[inline]
        pub unsafe fn $set(o: Obj, offset: u32, v: $t) {
            debug_check_live(o, "field write");
            ptr::write_unaligned(
                (lean_ctor_obj_cptr(o) as *mut u8).add(offset as usize) as *mut $t,
                v,
            )
        }
    };
}

ctor_scalar!(lean_ctor_get_uint8, lean_ctor_set_uint8, u8);
ctor_scalar!(lean_ctor_get_uint16, lean_ctor_set_uint16, u16);
ctor_scalar!(lean_ctor_get_uint32, lean_ctor_set_uint32, u32);
ctor_scalar!(lean_ctor_get_uint64, lean_ctor_set_uint64, u64);
ctor_scalar!(lean_ctor_get_float, lean_ctor_set_float, f64);
ctor_scalar!(lean_ctor_get_float32, lean_ctor_set_float32, f32);

/* Boxing of scalars that do not fit a tagged pointer */

#[inline]
pub unsafe fn lean_box_uint32(v: u32) -> Obj {
    lean_box(v as usize)
}

#[inline]
pub unsafe fn lean_unbox_uint32(o: Obj) -> u32 {
    lean_unbox(o) as u32
}

#[inline]
pub unsafe fn lean_box_uint64(v: u64) -> Obj {
    let r = lean_alloc_ctor(0, 0, 8);
    lean_ctor_set_uint64(r, 0, v);
    r
}

#[inline]
pub unsafe fn lean_unbox_uint64(o: Obj) -> u64 {
    lean_ctor_get_uint64(o, 0)
}

#[inline]
pub unsafe fn lean_box_usize(v: usize) -> Obj {
    let r = lean_alloc_ctor(0, 0, size_of::<usize>() as u32);
    lean_ctor_set_usize(r, 0, v);
    r
}

#[inline]
pub unsafe fn lean_unbox_usize(o: Obj) -> usize {
    lean_ctor_get_usize(o, 0)
}

#[inline]
pub unsafe fn lean_box_float(v: f64) -> Obj {
    let r = lean_alloc_ctor(0, 0, 8);
    lean_ctor_set_float(r, 0, v);
    r
}

#[inline]
pub unsafe fn lean_unbox_float(o: Obj) -> f64 {
    lean_ctor_get_float(o, 0)
}

#[inline]
pub unsafe fn lean_box_float32(v: f32) -> Obj {
    let r = lean_alloc_ctor(0, 0, 4);
    lean_ctor_set_float32(r, 0, v);
    r
}

#[inline]
pub unsafe fn lean_unbox_float32(o: Obj) -> f32 {
    lean_ctor_get_float32(o, 0)
}

/* Ref objects (`ST.Ref`) */

#[inline]
pub unsafe fn lean_alloc_ref(v: Obj) -> Obj {
    let o = lean_alloc_small_object(size_of::<RefObject>());
    lean_set_st_header(o, LEAN_REF as u32, 0);
    (*(o as *mut RefObject)).m_value = v;
    o
}

/* External objects */

#[inline]
pub unsafe fn lean_alloc_external(cls: *const ExternalClass, data: *mut c_void) -> Obj {
    let o = lean_alloc_small_object(size_of::<ExternalObject>());
    lean_set_st_header(o, LEAN_EXTERNAL as u32, 0);
    let e = o as *mut ExternalObject;
    (*e).m_class = cls;
    (*e).m_data = data;
    o
}

#[inline]
pub unsafe fn lean_get_external_class(o: Obj) -> *const ExternalClass {
    (*(o as *mut ExternalObject)).m_class
}

#[inline]
pub unsafe fn lean_get_external_data(o: Obj) -> *mut c_void {
    (*(o as *mut ExternalObject)).m_data
}

pub unsafe fn lean_set_external_data(o: Obj, data: *mut c_void) -> Obj {
    if lean_is_exclusive(o) {
        (*(o as *mut ExternalObject)).m_data = data;
        o
    } else {
        let r = lean_alloc_external(lean_get_external_class(o), data);
        lean_dec_ref(o);
        r
    }
}

/* Helpers shared by the other modules */

#[inline]
pub unsafe fn lean_closure_arg_cptr(o: Obj) -> *mut Obj {
    (o as *mut u8).add(offset_of!(ClosureObject, m_objs)) as *mut Obj
}

#[inline]
pub unsafe fn lean_array_cptr(o: Obj) -> *mut Obj {
    (o as *mut u8).add(offset_of!(ArrayObject, m_data)) as *mut Obj
}

#[inline]
pub unsafe fn lean_sarray_elem_size(o: Obj) -> u32 {
    ((*o).m_other & !LEAN_LINEAR_MARK_MASK) as u32
}

pub use crate::panic::{
    lean_internal_panic, lean_internal_panic_out_of_memory, lean_internal_panic_rc_overflow,
    lean_internal_panic_unreachable,
};

/// Frees the memory of `o` unless it is a scalar (`del` in the IR).
#[inline]
pub unsafe fn lean_del_object(o: Obj) {
    if !lean_is_scalar(o) {
        lean_free_object(o);
    }
}
