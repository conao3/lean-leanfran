//! Calls the public functions generated from `LeanRustTest.Public`.

use lean_rust::{Int, Nat};
use lean_rust_public_test as p;
use std::process::Command;

fn nat(n: u64) -> Nat {
    n.into()
}

#[test]
fn numbers() {
    assert_eq!(p::double(nat(21)), nat(42));
    assert!(p::is_even(nat(10)));
    assert!(!p::is_even(nat(7)));
    assert_eq!(p::negate(Int::from(5)), Int::from(-5));
    assert_eq!(p::mix(1, 2, 3, 4, 5), 15);
    assert_eq!(p::signed(-1, -2, -3, -4, -5), -15);
    assert_eq!(p::halve(3.0), 1.5);
    assert_eq!(p::halve32(5.0), 2.5);
    assert_eq!(p::r#type(nat(7)), nat(7));
    assert_eq!(p::double_prime(nat(4)), nat(8));
}

#[test]
fn nat_bignum() {
    let big: Nat = "1267650600228229401496703205376".parse().unwrap();
    assert_eq!(p::big(), big);
    assert_eq!(p::answer(), nat(42));
    let x: Nat = "123456789012345678901234567890".parse().unwrap();
    assert_eq!(p::double(x).to_string(), "246913578024691357802469135780");
    assert_eq!(
        u64::try_from(p::double(nat(u64::MAX))),
        Err(lean_rust::runtime::OutOfRange)
    );
    assert_eq!(p::double(nat(u64::MAX)).to_string(), "36893488147419103230");
}

#[test]
fn chars_and_strings() {
    assert_eq!(p::next_char('a'), 'b');
    assert_eq!(p::next_char('ぁ'), 'あ');
    assert_eq!(p::greet("世界"), "こんにちは, 世界! (2)");
    assert_eq!(p::greet(String::from("Lean")), "こんにちは, Lean! (4)");
    p::unit(());
}

#[test]
fn structures() {
    let q = p::point_add(
        p::Point {
            x: nat(1),
            y: Int::from(-2),
        },
        p::Point {
            x: nat(3),
            y: Int::from(5),
        },
    );
    assert_eq!(
        q,
        p::Point {
            x: nat(4),
            y: Int::from(3)
        }
    );
    let s = p::Sample {
        name: "s".into(),
        count: 7,
        weight: 1.5,
        flag: true,
        tags: vec!["a".into(), "β".into()],
    };
    assert_eq!(p::sample_describe(s.clone()), "s:7:1.500000:true:[a, β]");
    let b = p::sample_bump(s);
    assert_eq!(b.count, 8);
    assert!(!b.flag);
    assert_eq!(b.tags, vec!["a".to_string(), "β".to_string()]);
    assert_eq!(
        p::meters_twice(p::Meters { val: 21 }),
        p::Meters { val: 42 }
    );
}

#[test]
fn enums() {
    assert_eq!(p::color_next(p::Color::Blue), p::Color::Red);
    assert_eq!(
        p::shape_area(p::Shape::Rect {
            width: nat(3),
            height: nat(4)
        }),
        nat(12)
    );
    assert_eq!(p::shape_area(p::Shape::Circle { radius: nat(2) }), nat(12));
    assert_eq!(p::shape_area(p::Shape::Dot), nat(0));
    let t = p::tree_of_list(vec![nat(5), nat(2), nat(8), nat(1)]);
    assert_eq!(
        p::tree_to_list(t.clone()),
        vec![nat(1), nat(2), nat(5), nat(8)]
    );
    let t = p::tree_insert(t, nat(3));
    match &t {
        p::Tree::Node { value, .. } => assert_eq!(*value, nat(5)),
        p::Tree::Leaf => panic!("expected a node"),
    }
    assert_eq!(p::tree_to_list(t).len(), 5);
}

#[test]
fn containers() {
    assert_eq!(p::sum_list(vec![nat(1), nat(2), nat(3)]), nat(6));
    assert_eq!(p::sum_list(vec![]), nat(0));
    assert_eq!(
        p::evens(vec![
            Int::from(1),
            Int::from(-2),
            Int::from(4),
            Int::from(5)
        ]),
        vec![Int::from(-2), Int::from(4)]
    );
    assert_eq!(
        p::find_q(vec![nat(1), nat(5), nat(9)], nat(4)),
        Some(nat(5))
    );
    assert_eq!(p::find_q(vec![nat(1)], nat(4)), None);
    assert_eq!(p::safe_div(nat(7), nat(2)), Ok(nat(3)));
    assert_eq!(
        p::safe_div(nat(7), nat(0)),
        Err("division by zero".to_string())
    );
    assert_eq!(p::swap((nat(1), "one".into())), ("one".to_string(), nat(1)));
    assert_eq!(p::first_bang(vec![nat(9), nat(8)]), nat(9));
}

#[test]
fn fin() {
    assert_eq!(p::pick(2), "two");
}

#[test]
fn fin_with_a_bound_that_reduces_to_a_literal() {
    assert_eq!(p::pick_pow(3), nat(30));
}

#[test]
fn fin_above_usize_is_a_nat() {
    let max = "1180591620717411303423".parse::<lean_rust::Nat>().unwrap();
    assert_eq!(p::big_fin(nat(41)), nat(42));
    assert_eq!(p::big_fin(max), nat(0));
}

#[test]
#[should_panic(expected = "Fin 3: index 3 is out of range")]
fn fin_out_of_range_panics() {
    p::pick(3);
}

#[test]
fn instance_argument() {
    assert_eq!(p::with_inst(nat(5)), nat(5));
}

#[test]
fn csimp_replacement_is_called() {
    assert_eq!(p::slow_length(vec![nat(1), nat(2), nat(3)]), nat(3));
    let start = p::SOURCE.find("pub fn slow_length(").unwrap();
    let body = &p::SOURCE[start..start + p::SOURCE[start..].find("\n}\n").unwrap()];
    assert!(body.contains("l_LeanRustTest_Public_fastLength("), "{body}");
    assert!(
        !body.contains("l_LeanRustTest_Public_slowLength("),
        "{body}"
    );
}

#[test]
fn skipped_definitions_are_not_public() {
    for name in [
        "pub fn compose(",
        "pub fn generic(",
        "pub fn positive(",
        "pub fn last_index(",
    ] {
        assert!(!p::SOURCE.contains(name), "{name}");
    }
}

#[test]
fn io_functions() {
    let out = Command::new(env!("CARGO_BIN_EXE_public-io"))
        .output()
        .unwrap();
    assert!(out.status.success());
    assert_eq!(
        String::from_utf8(out.stdout).unwrap(),
        "hello from Lean, Rust\nreturned 4\ncounter 10\nerror Other: failed with 3\ndone\n"
    );
}

#[test]
fn instantiated_polymorphic_functions() {
    assert_eq!(p::largest(vec![nat(3), nat(9), nat(4)]), nat(9));
    assert_eq!(
        p::largest(vec!["pear".to_string(), "apple".to_string()]),
        "pear"
    );
    assert_eq!(p::largest(vec![Int::from(-3), Int::from(5)]), Int::from(5));
    assert_eq!(p::largest::<Int>(vec![]), Int::from(0));
    assert_eq!(
        p::pair_with(nat(1), vec!["a".to_string(), "b".to_string()]),
        vec![(nat(1), "a".to_string()), (nat(1), "b".to_string())]
    );
    assert_eq!(
        p::pair_with("x".to_string(), vec![true]),
        vec![("x".to_string(), true)]
    );
    assert!(p::same(true));
    assert_eq!(p::largest_inst_nat(vec![nat(2), nat(1)]), nat(2));
}

#[test]
fn instantiations_are_replaced_by_csimp() {
    assert_eq!(p::same(nat(7)), nat(7));
    assert_eq!(p::__lean_rust_spec::same(nat(7)), nat(7));
    let start = p::SOURCE.find("pub fn same_inst_nat(").unwrap();
    let body = &p::SOURCE[start..start + p::SOURCE[start..].find("\n}\n").unwrap()];
    assert!(body.contains("l_LeanRustTest_Public_sameNat("), "{body}");
}
