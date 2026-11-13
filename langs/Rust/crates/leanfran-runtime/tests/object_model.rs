//! Object model, reference counting and closures.

use leanfran_runtime::*;

unsafe fn nat(n: usize) -> Obj {
    lean_usize_to_nat(n)
}

unsafe fn pair(a: Obj, b: Obj) -> Obj {
    let o = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(o, 0, a);
    lean_ctor_set(o, 1, b);
    o
}

#[test]
fn scalars_are_tagged() {
    let o = lean_box(42);
    assert!(lean_is_scalar(o));
    assert_eq!(lean_unbox(o), 42);
    assert_eq!(o.addr(), (42 << 1) | 1);
    unsafe {
        assert_eq!(lean_obj_tag(lean_box(3)), 3);
        lean_inc(o);
        lean_dec(o);
    }
}

#[test]
fn header_layout_matches_lean_h() {
    assert_eq!(core::mem::size_of::<Object>(), 8);
    assert_eq!(core::mem::offset_of!(Object, m_cs_sz), 4);
    assert_eq!(core::mem::offset_of!(Object, m_other), 6);
    assert_eq!(core::mem::offset_of!(Object, m_tag), 7);
    assert_eq!(core::mem::size_of::<ArrayObject>(), 24);
    assert_eq!(core::mem::size_of::<StringObject>(), 32);
    assert_eq!(core::mem::size_of::<ClosureObject>(), 24);
    assert_eq!(core::mem::offset_of!(ClosureObject, m_arity), 16);
}

#[test]
fn ctor_fields_and_scalars() {
    unsafe {
        let o = lean_alloc_ctor(3, 1, 8 + 4 + 2 + 1);
        lean_ctor_set(o, 0, lean_box(7));
        lean_ctor_set_uint64(o, 8, u64::MAX - 1);
        lean_ctor_set_uint32(o, 8 + 8, 0xdead_beef);
        lean_ctor_set_uint16(o, 8 + 12, 0xbeef);
        lean_ctor_set_uint8(o, 8 + 14, 0xab);
        assert_eq!(lean_obj_tag(o), 3);
        assert_eq!(lean_ctor_num_objs(o), 1);
        assert_eq!(lean_unbox(lean_ctor_get(o, 0)), 7);
        assert_eq!(lean_ctor_get_uint64(o, 8), u64::MAX - 1);
        assert_eq!(lean_ctor_get_uint32(o, 16), 0xdead_beef);
        assert_eq!(lean_ctor_get_uint16(o, 20), 0xbeef);
        assert_eq!(lean_ctor_get_uint8(o, 22), 0xab);
        lean_ctor_set_tag(o, 1);
        assert_eq!(lean_obj_tag(o), 1);
        lean_dec(o);
    }
}

#[test]
fn boxed_scalars_round_trip() {
    unsafe {
        let a = lean_box_uint64(u64::MAX);
        let b = lean_box_float(-2.5);
        let c = lean_box_float32(1.25);
        let d = lean_box_usize(usize::MAX);
        assert_eq!(lean_unbox_uint64(a), u64::MAX);
        assert_eq!(lean_unbox_float(b), -2.5);
        assert_eq!(lean_unbox_float32(c), 1.25);
        assert_eq!(lean_unbox_usize(d), usize::MAX);
        assert_eq!(lean_unbox_uint32(lean_box_uint32(u32::MAX)), u32::MAX);
        for o in [a, b, c, d] {
            lean_dec(o);
        }
    }
}

#[test]
fn reference_counts_and_exclusivity() {
    unsafe {
        let o = pair(lean_box(1), lean_box(2));
        assert!(lean_is_exclusive(o));
        lean_inc(o);
        assert!(!lean_is_exclusive(o));
        lean_inc_n(o, 3);
        assert_eq!((*o).m_rc, 5);
        for _ in 0..4 {
            lean_dec(o);
        }
        assert!(lean_is_exclusive(o));
        lean_dec(o);
    }
}

#[test]
fn freeing_releases_children() {
    unsafe {
        let child = pair(lean_box(1), lean_box(2));
        lean_inc(child);
        let parent = pair(child, lean_alloc_array(0, 4));
        lean_dec(parent);
        assert!(lean_is_exclusive(child));
        lean_dec(child);
    }
}

#[test]
fn long_lists_are_freed_without_recursion() {
    unsafe {
        let mut l = lean_box(0);
        for i in 0..if cfg!(miri) { 1000 } else { 1_000_000 } {
            l = pair(lean_box(i), l);
        }
        lean_dec(l);
    }
}

#[test]
fn persistent_objects_ignore_reference_counting() {
    unsafe {
        let inner = pair(lean_box(1), lean_box(2));
        let o = pair(inner, lean_mk_string("persistent"));
        lean_mark_persistent(o);
        assert_eq!((*o).m_rc, 0);
        assert_eq!((*inner).m_rc, 0);
        lean_inc(o);
        lean_dec(o);
        lean_dec(o);
        assert!(!lean_is_exclusive(o));
        assert_eq!(lean_unbox(lean_ctor_get(lean_ctor_get(o, 0), 1)), 2);
    }
}

#[test]
fn ctor_release_and_del_object() {
    unsafe {
        let child = pair(lean_box(1), lean_box(2));
        let o = pair(child, lean_box(5));
        lean_ctor_release(o, 0);
        assert!(lean_is_scalar(lean_ctor_get(o, 0)));
        lean_del_object(o);
        lean_del_object(lean_box(0));
    }
}

#[cfg(debug_assertions)]
mod rc_errors {
    use super::*;

    #[test]
    #[cfg_attr(miri, ignore)]
    #[should_panic(expected = "decrement of the freed object")]
    fn decrement_after_free_panics() {
        unsafe {
            let o = pair(lean_box(1), lean_box(2));
            lean_dec(o);
            lean_dec(o);
        }
    }

    #[test]
    #[cfg_attr(miri, ignore)]
    #[should_panic(expected = "increment of the freed object")]
    fn increment_after_free_panics() {
        unsafe {
            let o = pair(lean_box(1), lean_box(2));
            lean_dec(o);
            lean_inc(o);
        }
    }

    #[test]
    #[cfg_attr(miri, ignore)]
    #[should_panic(expected = "field read of the freed object")]
    fn field_read_after_free_panics() {
        unsafe {
            let o = pair(lean_box(1), lean_box(2));
            lean_dec(o);
            lean_ctor_get(o, 0);
        }
    }

    #[test]
    #[cfg_attr(miri, ignore)]
    #[should_panic(expected = "decrement of the freed object")]
    fn child_freed_twice_panics() {
        unsafe {
            let child = pair(lean_box(1), lean_box(2));
            let parent = pair(child, lean_box(0));
            lean_dec(child);
            lean_dec(parent);
        }
    }

    #[test]
    #[cfg_attr(miri, ignore)]
    #[should_panic(expected = "application of the freed object")]
    fn applying_a_freed_closure_panics() {
        unsafe {
            let c = lean_alloc_closure(add2 as *const (), 2, 0);
            lean_dec(c);
            lean_apply_2(c, nat(1), nat(2));
        }
    }
}

/* Closures */

unsafe fn add2(a: Obj, b: Obj) -> Obj {
    let r = lean_nat_add(a, b);
    lean_dec(a);
    lean_dec(b);
    r
}

unsafe fn add3(a: Obj, b: Obj, c: Obj) -> Obj {
    let ab = add2(a, b);
    add2(ab, c)
}

/// Returns a closure adding `a`.
unsafe fn adder(a: Obj) -> Obj {
    let c = lean_alloc_closure(add2 as *const (), 2, 1);
    lean_closure_set(c, 0, a);
    c
}

unsafe fn sum17(args: *mut Obj) -> Obj {
    let mut acc = lean_box(0);
    for i in 0..17 {
        let a = *args.add(i);
        acc = add2(acc, a);
    }
    acc
}

#[test]
fn exact_application() {
    unsafe {
        let c = lean_alloc_closure(add3 as *const (), 3, 0);
        assert_eq!(lean_unbox(lean_apply_3(c, nat(1), nat(2), nat(3))), 6);
    }
}

#[test]
fn partial_application_builds_closures() {
    unsafe {
        let c = lean_alloc_closure(add3 as *const (), 3, 0);
        let c1 = lean_apply_1(c, nat(10));
        assert_eq!(lean_closure_num_fixed(c1), 1);
        lean_inc(c1);
        let c2 = lean_apply_1(c1, nat(20));
        assert_eq!(lean_closure_num_fixed(c2), 2);
        assert_eq!(lean_unbox(lean_apply_1(c2, nat(30))), 60);
        assert_eq!(lean_unbox(lean_apply_2(c1, nat(1), nat(2))), 13);
    }
}

#[test]
fn shared_closures_keep_their_fixed_arguments() {
    unsafe {
        let big = lean_cstr_to_nat("100000000000000000000000");
        let c = adder(big);
        lean_inc(c);
        let r1 = lean_apply_1(c, nat(1));
        let r2 = lean_apply_1(c, nat(2));
        assert_eq!(lean_string_to_str(nat_repr(r1)), "100000000000000000000001");
        assert_eq!(lean_string_to_str(nat_repr(r2)), "100000000000000000000002");
    }
}

#[test]
fn over_application_applies_the_result() {
    unsafe {
        // `make_adder a` returns a closure; applying `make_adder` to two arguments applies it.
        let c = lean_alloc_closure(adder as *const (), 1, 0);
        assert_eq!(lean_unbox(lean_apply_2(c, nat(4), nat(5))), 9);
    }
}

#[test]
fn erased_function_application_returns_it() {
    unsafe {
        let s = lean_mk_string("dropped");
        assert_eq!(lean_apply_1(lean_box(0), s), lean_box(0));
    }
}

#[test]
fn more_than_sixteen_arguments_use_an_array() {
    unsafe {
        let c = lean_alloc_closure(sum17 as *const (), 17, 0);
        let c = lean_apply_4(c, nat(1), nat(2), nat(3), nat(4));
        lean_inc(c);
        let mut rest: Vec<Obj> = (5..=17).map(|i| nat(i)).collect();
        assert_eq!(lean_unbox(lean_apply_m(c, 13, rest.as_mut_ptr())), 153);
        let mut rest: Vec<Obj> = (5..=17).map(|i| nat(i * 2)).collect();
        assert_eq!(
            lean_unbox(lean_apply_n(c, 13, rest.as_mut_ptr())),
            10 + 2 * 143
        );
    }
}

unsafe fn nat_repr(n: Obj) -> Obj {
    let s = nat_value_string(n);
    lean_dec(n);
    lean_mk_string(&s)
}

unsafe fn nat_value_string(n: Obj) -> String {
    if lean_is_scalar(n) {
        lean_unbox(n).to_string()
    } else {
        lean_mpz_value(n).to_string()
    }
}

/* Thunks, tasks, refs */

unsafe fn const_42(_unit: Obj) -> Obj {
    nat(42)
}

#[test]
fn thunks_evaluate_once() {
    unsafe {
        let t = lean_mk_thunk(lean_alloc_closure(const_42 as *const (), 1, 0));
        assert_eq!(lean_unbox(lean_thunk_get_own(t)), 42);
        assert_eq!(lean_unbox(lean_thunk_get(t)), 42);
        lean_dec(t);
        let p = lean_thunk_pure(lean_mk_string("ready"));
        assert_eq!(lean_string_to_str(lean_thunk_get(p)), "ready");
        lean_dec(p);
    }
}

#[test]
fn tasks_run_synchronously() {
    unsafe {
        let t = lean_task_spawn(lean_alloc_closure(const_42 as *const (), 1, 0), lean_box(0));
        lean_inc(t);
        assert_eq!(lean_unbox(lean_task_get_own(t)), 42);
        let m = lean_task_map(adder(nat(1)), t, lean_box(0), 0);
        assert_eq!(lean_unbox(lean_task_get_own(m)), 43);
    }
}

#[test]
fn st_refs() {
    unsafe {
        let r = lean_st_mk_ref(lean_mk_string("a"));
        let v = lean_st_ref_get(r);
        assert_eq!(lean_string_to_str(v), "a");
        lean_dec(v);
        lean_st_ref_put(r, nat(1));
        let old = lean_st_ref_swap(r, nat(2));
        assert_eq!(lean_unbox(old), 1);
        assert_eq!(lean_unbox(lean_st_ref_take(r)), 2);
        assert_eq!(lean_st_ref_ptr_eq(r, r), 1);
        lean_st_ref_put(r, lean_box(0));
        lean_dec(r);
    }
}

#[test]
fn standard_streams_are_structures_of_closures() {
    unsafe {
        let out = lean_get_stdout();
        assert_eq!(lean_ctor_num_objs(out), 6);
        let put_str = lean_ctor_get(out, 4);
        lean_inc(put_str);
        let r = lean_apply_2(put_str, lean_mk_string(""), lean_box(0));
        assert!(lean_io_result_is_ok(r));
        lean_dec(r);
        lean_dec(out);
    }
}

#[test]
fn static_str_is_a_slice_of_its_bytes() {
    unsafe {
        let s = "duckdb".to_model();
        assert_eq!(Vec::<u8>::from_model(s), b"duckdb");
        assert_eq!(<&'static str>::from_model(s), "duckdb");
        lean_dec(s);
    }
}

#[test]
fn string_is_a_lean_string() {
    unsafe {
        let t = String::from("héllo").to_model();
        assert_eq!(lean_string_to_str(t), "héllo");
        assert_eq!(String::from_model(t), "héllo");
        lean_dec(t);
    }
}
