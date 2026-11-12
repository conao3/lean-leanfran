use lean_rust_verify_test::counter::Counter;
use lean_rust_verify_test::effects;
use lean_rust_verify_test::generic::Pair;
use lean_rust_verify_test::spec::{calls, counters, generic_specs, pairs, specs};

#[test]
fn a_proved_refines_makes_the_spec_run_the_rust_function() {
    let before = effects::traces();
    assert_eq!(specs::bigger(3, 5), 5);
    assert_eq!(specs::bigger(9, 5), 9);
    assert_eq!(effects::traces(), before + 2);
    assert_eq!(specs::__lean_rust_spec::bigger(9, 5), 9);
    assert_eq!(effects::traces(), before + 2);
}

#[test]
fn an_unproved_refines_keeps_the_lean_spec() {
    assert_eq!(specs::double(21), 42);
    assert_eq!(specs::double(u32::MAX), u32::MAX - 1);
}

#[test]
fn a_struct_crosses_to_lean_and_back() {
    let c = Counter {
        count: 7,
        active: true,
    };
    let zero = Counter {
        count: 0,
        active: true,
    };
    assert_eq!(counters::__lean_rust_spec::reset(c.clone()), zero);
    assert_eq!(counters::reset(c), zero);
}

#[test]
fn lean_calls_the_rust_function_and_sees_a_panic_as_fail() {
    assert!(calls::runs(3));
    assert!(!calls::runs(7));
}

#[test]
fn an_array_crosses_to_lean_and_back() {
    assert_eq!(specs::arr_sum([1, 2, u32::MAX]), 3 + u32::MAX as u64);
    assert_eq!(specs::arr_fill(7), [7, 7, 7]);
}

#[test]
fn a_generic_spec_runs_for_its_instances() {
    assert!(generic_specs::max_ge(3u32, 5, 5));
    assert!(!generic_specs::max_ge(-3i64, 5, 4));
    assert_eq!(generic_specs::larger(3u32, 5), 5);
    assert_eq!(generic_specs::larger(-3i64, -5), -3);
    assert_eq!(generic_specs::__lean_rust_spec::larger(3u32, 5), 5);
}

#[test]
fn a_per_instance_proof_replaces_its_instantiation() {
    let src = include_str!(concat!(
        env!("OUT_DIR"),
        "/lean_rust/cdda342bf128cef0/generic_specs.rs"
    ));
    let start = src.find("pub fn larger_inst_u32(").unwrap();
    let body = &src[start..start + src[start..].find("\n}\n").unwrap()];
    assert!(body.contains("crate::generic::larger::<u32>("), "{body}");
    let start = src.find("pub fn larger_inst_i64(").unwrap();
    let body = &src[start..start + src[start..].find("\n}\n").unwrap()];
    assert!(!body.contains("crate::generic::larger"), "{body}");
}

#[test]
fn a_generic_struct_crosses_to_lean_and_back() {
    let p = Pair { a: 1u32, b: 2 };
    assert_eq!(pairs::swapped(p), Pair { a: 2, b: 1 });
    assert_eq!(pairs::__lean_rust_spec::swapped(p), Pair { a: 2, b: 1 });
}
