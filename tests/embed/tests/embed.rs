//! Calls the functions of the `lean!` blocks.

use lean_rust::Nat;
use lean_rust_embed_test::{arith, counts, geometry::shapes, scaled};

fn nat(n: u64) -> Nat {
    n.into()
}

#[test]
fn proved_functions_run() {
    assert_eq!(arith::double(21u64.into()), 42u64.into());
    assert_eq!(arith::sum_to(nat(100)), nat(5050));
}

#[test]
fn imports_are_available() {
    let words = ["b", "a", "b", "c", "b"].map(String::from).to_vec();
    assert_eq!(
        counts::tally(words),
        vec![
            ("a".into(), nat(1)),
            ("b".into(), nat(3)),
            ("c".into(), nat(1))
        ]
    );
}

#[test]
fn blocks_use_other_blocks() {
    let p = shapes::Point {
        x: nat(2),
        y: nat(5),
    };
    assert_eq!(shapes::point_manhattan(p.clone()), nat(7));
    let q = scaled::double_both(shapes::Point {
        x: nat(2),
        y: nat(5),
    });
    assert_eq!(
        q,
        shapes::Point {
            x: nat(4),
            y: nat(10)
        }
    );
    assert_eq!(scaled::scale(q, nat(3)).x, nat(12));
}

#[test]
fn instantiated_functions_are_generic() {
    use lean_rust_embed_test::generic;
    assert_eq!(
        generic::count_of(vec![nat(1), nat(2), nat(1)], nat(1)),
        nat(2)
    );
    assert_eq!(
        generic::count_of(vec!["a".to_string(), "b".to_string()], "b".to_string()),
        nat(1)
    );
}
