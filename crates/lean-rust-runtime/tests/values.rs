//! Numbers, strings, arrays and floats against the C runtime's results.

use lean_rust_runtime::*;

unsafe fn nat(s: &str) -> Obj {
    lean_cstr_to_nat(s)
}

unsafe fn int(s: &str) -> Obj {
    lean_cstr_to_int(s)
}

unsafe fn show(o: Obj) -> String {
    if lean_is_scalar(o) {
        lean_unbox(o).to_string()
    } else {
        lean_mpz_value(o).to_string()
    }
}

unsafe fn show_int(o: Obj) -> String {
    if lean_is_scalar(o) {
        lean_scalar_to_int64(o).to_string()
    } else {
        lean_mpz_value(o).to_string()
    }
}

/// Applies a borrowing binary operation and frees the arguments and the result.
unsafe fn nat_op(f: unsafe fn(Obj, Obj) -> Obj, a: &str, b: &str) -> String {
    let (x, y) = (nat(a), nat(b));
    let r = f(x, y);
    let s = show(r);
    lean_dec(x);
    lean_dec(y);
    lean_dec(r);
    s
}

unsafe fn int_op(f: unsafe fn(Obj, Obj) -> Obj, a: &str, b: &str) -> String {
    let (x, y) = (int(a), int(b));
    let r = f(x, y);
    let s = show_int(r);
    lean_dec(x);
    lean_dec(y);
    lean_dec(r);
    s
}

#[test]
fn nat_arithmetic() {
    unsafe {
        assert_eq!(nat_op(lean_nat_sub, "10", "20"), "0");
        assert_eq!(nat_op(lean_nat_div, "10", "0"), "0");
        assert_eq!(nat_op(lean_nat_mod, "10", "0"), "10");
        assert_eq!(
            nat_op(lean_nat_pow, "2", "100"),
            "1267650600228229401496703205376"
        );
        assert_eq!(nat_op(lean_nat_gcd, "84", "36"), "12");
        assert_eq!(
            nat_op(lean_nat_mul, "1000000007", "1000000009"),
            "1000000016000000063"
        );
        assert_eq!(
            nat_op(lean_nat_mul, "9223372036854775807", "2"),
            "18446744073709551614"
        );
        assert_eq!(
            nat_op(lean_nat_add, "9223372036854775807", "1"),
            "9223372036854775808"
        );
        assert_eq!(
            nat_op(lean_nat_div, "1180591620717411303424", "8"),
            "147573952589676412928"
        );
        assert_eq!(
            nat_op(lean_nat_mod, "1180591620717411303424", "1000"),
            "424"
        );
        assert_eq!(nat_op(lean_nat_shiftl, "1", "65"), "36893488147419103232");
        assert_eq!(nat_op(lean_nat_shiftr, "73786976294838206464", "60"), "64");
        assert_eq!(nat_op(lean_nat_shiftr, "5", "64"), "0");
        assert_eq!(nat_op(lean_nat_land, "255", "15"), "15");
        assert_eq!(nat_op(lean_nat_lor, "240", "15"), "255");
        assert_eq!(nat_op(lean_nat_lxor, "5", "3"), "6");
        assert_eq!(
            nat_op(lean_nat_sub, "36893488147419103232", "36893488147419103231"),
            "1"
        );
        let n = nat("1025");
        assert_eq!(show(lean_nat_log2(n)), "10");
        let n = nat("36893488147419103232");
        assert_eq!(show(lean_nat_log2(n)), "65");
        lean_dec(n);
    }
}

#[test]
fn small_nats_are_scalars_and_big_ones_mpz() {
    unsafe {
        let max = lean_usize_to_nat(LEAN_MAX_SMALL_NAT);
        assert!(lean_is_scalar(max));
        let big = lean_usize_to_nat(LEAN_MAX_SMALL_NAT + 1);
        assert!(!lean_is_scalar(big));
        let back = lean_nat_sub(big, lean_box(1));
        assert!(lean_is_scalar(back));
        assert_eq!(lean_nat_dec_eq(back, max), 1);
        assert_eq!(lean_nat_dec_lt(max, big), 1);
        assert_eq!(lean_nat_dec_le(big, max), 0);
        lean_dec(big);
    }
}

#[test]
fn int_division_conventions() {
    unsafe {
        assert_eq!(int_op(lean_int_ediv, "-7", "2"), "-4");
        assert_eq!(int_op(lean_int_emod, "-7", "2"), "1");
        assert_eq!(int_op(lean_int_ediv, "7", "-2"), "-3");
        assert_eq!(int_op(lean_int_emod, "7", "-2"), "1");
        assert_eq!(int_op(lean_int_div, "-7", "2"), "-3");
        assert_eq!(int_op(lean_int_mod, "-7", "2"), "-1");
        assert_eq!(int_op(lean_int_ediv, "-7", "0"), "0");
        assert_eq!(int_op(lean_int_emod, "-7", "0"), "-7");
        assert_eq!(
            int_op(lean_int_ediv, "-100000000000000000000", "3"),
            "-33333333333333333334"
        );
        assert_eq!(int_op(lean_int_emod, "-100000000000000000000", "3"), "2");
        assert_eq!(int_op(lean_int_mul, "-2147483648", "-1"), "2147483648");
        assert_eq!(int_op(lean_int_sub, "-2147483648", "1"), "-2147483649");
    }
}

#[test]
fn small_ints_follow_lean_h() {
    unsafe {
        let m = lean_int64_to_int(i32::MIN as i64);
        assert!(lean_is_scalar(m));
        let n = lean_int_neg(m);
        assert!(!lean_is_scalar(n));
        assert_eq!(show_int(n), "2147483648");
        let back = lean_int_neg(n);
        assert!(lean_is_scalar(back));
        assert_eq!(lean_int_dec_eq(back, m), 1);
        lean_dec(n);
        let big_nat = lean_usize_to_nat(1 << 40);
        let i = lean_nat_to_int(big_nat);
        assert!(!lean_is_scalar(i));
        let abs = lean_nat_abs(i);
        assert!(lean_is_scalar(abs));
        assert_eq!(lean_unbox(abs), 1 << 40);
        lean_dec(i);
        let ns = lean_int_neg_succ_of_nat(lean_box(4));
        assert_eq!(show_int(ns), "-5");
    }
}

#[test]
fn fixed_width_integers_wrap() {
    unsafe {
        assert_eq!(lean_uint8_add(250, 10), 4);
        assert_eq!(lean_uint8_sub(3, 5), 254);
        assert_eq!(lean_uint64_div(u64::MAX, 3), 6148914691236517205);
        assert_eq!(lean_uint64_mod(7, 0), 7);
        assert_eq!(lean_uint64_div(7, 0), 0);
        assert_eq!(lean_uint64_shift_left(1, 63), 1 << 63);
        assert_eq!(lean_uint64_shift_left(1, 64), 1);
        assert_eq!(lean_uint32_complement(0), u32::MAX);
        let n = nat("300");
        assert_eq!(lean_uint8_of_nat(n), 44);
        let big = nat("18446744073709551617");
        assert_eq!(lean_uint64_of_nat(big), 1);
        assert_eq!(show(lean_uint64_to_nat(u64::MAX)), "18446744073709551615");
        lean_dec(big);
        assert_eq!(lean_int8_div(0x80, 0xff), 0x80);
        assert_eq!(lean_int64_mod(i64::MIN as u64, u64::MAX), 0);
        assert_eq!(lean_int8_shift_right(0x80, 1), 0xc0);
        assert_eq!(lean_int8_dec_lt(0xff, 0), 1);
    }
}

unsafe fn text(o: Obj) -> String {
    let s = lean_string_to_str(o).to_string();
    lean_dec(o);
    s
}

#[test]
fn float_to_string_is_c_percent_f() {
    unsafe {
        assert_eq!(text(lean_float_to_string(3.75)), "3.750000");
        assert_eq!(text(lean_float_to_string(f64::NAN)), "NaN");
        assert_eq!(text(lean_float_to_string(f64::INFINITY)), "inf");
        assert_eq!(text(lean_float_to_string(f64::NEG_INFINITY)), "-inf");
        assert_eq!(text(lean_float_to_string(-0.0)), "-0.000000");
        assert_eq!(
            text(lean_float_to_string(123456789.125)),
            "123456789.125000"
        );
        assert_eq!(text(lean_float_to_string(0.0000005)), "0.000000");
        assert_eq!(text(lean_float_to_string(2.5e-6)), "0.000003");
        assert_eq!(text(lean_float32_to_string(0.1f32 + 1.5f32)), "1.600000");
        assert_eq!(text(lean_float_to_string(sqrt(2.0))), "1.414214");
        assert_eq!(text(lean_float_to_string(exp(1.0))), "2.718282");
        assert_eq!(lean_float_to_uint64(-2.5), 0);
        assert_eq!(lean_float_to_uint64(1e30), u64::MAX);
        assert_eq!(lean_float_to_uint64(f64::NAN), 0);
        assert_eq!(
            lean_float_to_bits(lean_float_of_bits(0x7ff0_0000_0000_0001)),
            0x7ff8_0000_0000_0000
        );
    }
}

#[test]
fn strings_are_utf8_with_byte_positions() {
    unsafe {
        let s = lean_mk_string("aé日本🎉z");
        assert_eq!(lean_unbox(lean_string_length(s)), 6);
        assert_eq!(lean_unbox(lean_string_utf8_byte_size(s)), 14);
        assert_eq!(lean_string_utf8_get(s, lean_box(1)), 'é' as u32);
        assert_eq!(lean_string_utf8_get(s, lean_box(2)), 'A' as u32);
        assert_eq!(lean_string_utf8_get(s, lean_box(100)), 'A' as u32);
        assert_eq!(lean_unbox(lean_string_utf8_next(s, lean_box(1))), 3);
        assert_eq!(lean_unbox(lean_string_utf8_next(s, lean_box(14))), 15);
        assert_eq!(lean_unbox(lean_string_utf8_prev(s, lean_box(3))), 1);
        assert_eq!(
            text(lean_string_utf8_extract(s, lean_box(1), lean_box(9))),
            "é日本"
        );
        assert_eq!(
            text(lean_string_utf8_extract(s, lean_box(2), lean_box(9))),
            ""
        );
        assert_eq!(
            text(lean_string_utf8_extract(s, lean_box(1), lean_box(4))),
            "é日本🎉z"
        );
        assert_eq!(lean_string_utf8_at_end(s, lean_box(14)), 1);
        let t = lean_string_utf8_set(s, lean_box(0), '日' as u32);
        assert_eq!(lean_string_to_str(t), "日é日本🎉z");
        let t = lean_string_push(t, '!' as u32);
        let u = lean_mk_string("++");
        let t = lean_string_append(t, u);
        lean_dec(u);
        assert_eq!(lean_unbox(lean_string_length(t)), 9);
        assert_eq!(text(t), "日é日本🎉z!++");
    }
}

#[test]
fn shared_strings_are_copied_on_write() {
    unsafe {
        let s = lean_mk_string("abc");
        lean_inc(s);
        let t = lean_string_push(s, 'd' as u32);
        assert_eq!(lean_string_to_str(s), "abc");
        assert_eq!(text(t), "abcd");
        lean_dec(s);
    }
}

#[test]
fn string_comparison_and_hash() {
    unsafe {
        let a = lean_mk_string("lean");
        assert_eq!(lean_string_hash(a), 1471293241645535231);
        let b = lean_mk_string("leap");
        assert_eq!(lean_string_dec_lt(a, b), 1);
        assert_eq!(lean_string_dec_lt(b, a), 0);
        assert_eq!(lean_string_dec_eq(a, b), 0);
        let c = lean_mk_string("lea");
        assert_eq!(lean_string_dec_lt(c, a), 1);
        assert_eq!(
            lean_string_memcmp(a, b, lean_box(0), lean_box(0), lean_box(3)),
            1
        );
        for o in [a, b, c] {
            lean_dec(o);
        }
    }
}

#[test]
fn string_lists_and_bytes() {
    unsafe {
        let s = lean_mk_string("héllo");
        lean_inc(s);
        let cs = lean_string_data(s);
        let back = lean_string_mk(cs);
        assert_eq!(lean_string_dec_eq(s, back), 1);
        lean_dec(back);
        let bytes = lean_string_to_utf8(s);
        assert_eq!(lean_unbox(lean_byte_array_size(bytes)), 6);
        assert_eq!(lean_string_validate_utf8(bytes), 1);
        assert_eq!(text(lean_string_from_utf8_unchecked(bytes)), "héllo");
        lean_dec(s);
        assert_eq!(
            text(lean_string_of_usize(usize::MAX)),
            "18446744073709551615"
        );
    }
}

#[test]
fn arrays() {
    unsafe {
        let mut a = lean_mk_empty_array_with_capacity(lean_box(0));
        for i in 0..10 {
            a = lean_array_push(a, lean_box(i));
        }
        assert_eq!(lean_unbox(lean_array_get_size(a)), 10);
        lean_inc(a);
        let b = lean_array_set(a, lean_box(0), lean_box(42));
        assert_eq!(lean_unbox(lean_array_get_core(a, 0)), 0);
        assert_eq!(lean_unbox(lean_array_get_core(b, 0)), 42);
        let b = lean_array_swap(b, lean_box(0), lean_box(9));
        assert_eq!(lean_unbox(lean_array_get_core(b, 0)), 9);
        let b = lean_array_swap(b, lean_box(0), lean_box(99));
        let l = lean_array_to_list(b);
        let c = lean_array_mk(l);
        assert_eq!(lean_unbox(lean_array_fget(c, lean_box(9))), 42);
        lean_dec(c);
        let r = lean_mk_array(lean_box(3), lean_mk_string("x"));
        assert_eq!(lean_string_to_str(lean_array_get_core(r, 2)), "x");
        lean_dec(r);
        let p = lean_array_pop(a);
        assert_eq!(lean_array_size(p), 9);
        lean_dec(p);
    }
}

#[test]
fn byte_and_float_arrays() {
    unsafe {
        let a = lean_mk_empty_byte_array(lean_box(0));
        let a = lean_byte_array_push(a, 1);
        let a = lean_byte_array_push(a, 2);
        let a = lean_byte_array_push(a, 255);
        assert_eq!(lean_byte_array_get(a, lean_box(3)), 0);
        lean_inc(a);
        let b = lean_byte_array_set(a, lean_box(0), 9);
        assert_eq!(lean_byte_array_get(a, lean_box(0)), 1);
        assert_eq!(lean_byte_array_get(b, lean_box(0)), 9);
        let c = lean_byte_array_copy_slice(a, lean_box(1), b, lean_box(3), lean_box(10), 0);
        assert_eq!(lean_sarray_size(c), 5);
        assert_eq!(lean_byte_array_get(c, lean_box(4)), 255);
        lean_dec(a);
        lean_dec(c);
        let f = lean_mk_empty_float_array(lean_box(1));
        let f = lean_float_array_push(f, 1.5);
        let f = lean_float_array_push(f, 2.5);
        let f = lean_float_array_set(f, lean_box(0), 0.5);
        assert_eq!(lean_float_array_get(f, lean_box(0)), 0.5);
        assert_eq!(lean_float_array_get(f, lean_box(7)), 0.0);
        assert_eq!(lean_unbox(lean_float_array_size(f)), 2);
        lean_dec(f);
    }
}

#[test]
fn array_out_of_bounds_returns_the_default() {
    unsafe {
        let a = lean_mk_empty_array();
        let d = lean_mk_string("default");
        let r = lean_array_get(d, a, lean_box(3));
        assert_eq!(r, d);
        lean_dec(r);
        lean_dec(d);
        lean_dec(a);
    }
}
