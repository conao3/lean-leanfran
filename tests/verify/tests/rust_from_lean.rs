use lean_rust_verify_test::counter::Counter;
use lean_rust_verify_test::effects;
use lean_rust_verify_test::spec::{calls, counters, specs};

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
