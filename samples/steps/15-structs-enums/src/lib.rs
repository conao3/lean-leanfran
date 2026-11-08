//! Step 15: the crate's structs and enums in specs (`derive(lean_rust::Model)`).

/// A counter that stops at `max`.
#[derive(Clone, Debug, PartialEq, Eq, lean_rust::Model)]
pub struct Counter {
    pub count: u32,
    pub max: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, lean_rust::Model)]
pub enum Action {
    Add(u32),
    Reset,
}

pub mod spec {
    lean_rust::lean! {
        #[lean(imports = ["Aeneas", "LeanRustGen.Model.step_15_structs_enums.Types"])]
        pub mod counter;
        r#"
        open Aeneas Aeneas.Std step_15_structs_enums

        def apply (c : Counter) (a : Action) : Counter :=
          match a with
          | .Add n => { c with count := if c.max.val - c.count.val ≤ n.val then c.max else ⟨c.count.bv + n.bv⟩ }
          | .Reset => { c with count := 0#u32 }

        def within (c : Counter) (_a : Action) : Bool := decide (c.count.val ≤ c.max.val)
        "#
    }
}

use spec::counter;

/// The counter after the action: adding stops at `max`.
#[lean_rust::model(refines = counter::apply, requires = counter::within, strategy = crate::inputs)]
pub fn apply(c: Counter, a: Action) -> Counter {
    match a {
        Action::Add(n) => {
            let count = if c.max - c.count <= n {
                c.max
            } else {
                c.count + n
            };
            Counter { count, ..c }
        }
        Action::Reset => Counter { count: 0, ..c },
    }
}

#[cfg(test)]
fn inputs() -> impl lean_rust::check::proptest::strategy::Strategy<Value = (Counter, Action)> {
    use lean_rust::check::proptest::prelude::*;
    let counter = (any::<u32>(), any::<u32>()).prop_map(|(a, b)| Counter {
        count: a.min(b),
        max: a.max(b),
    });
    let action = prop_oneof![any::<u32>().prop_map(Action::Add), Just(Action::Reset)];
    (counter, action)
}
