# 15-structs-enums

Structs and enums of the crate derive `lean_rust::Model`, and Aeneas translates them to Lean
types (`lean/LeanRustGen/Model/step_15_structs_enums/Types.lean`) that specs use:

```rust
#[derive(Clone, Debug, PartialEq, Eq, lean_rust::Model)]
pub struct Counter { pub count: u32, pub max: u32 }

#[derive(Clone, Copy, Debug, PartialEq, Eq, lean_rust::Model)]
pub enum Action { Add(u32), Reset }
```

The spec block imports the generated types:

```rust
lean_rust::lean! {
    #[lean(imports = ["Aeneas", "LeanRustGen.Model.step_15_structs_enums.Types"])]
    pub mod counter;
    r#"
    open Aeneas Aeneas.Std step_15_structs_enums

    def apply (c : Counter) (a : Action) : Counter := ..
    "#
}
```

`apply` refines the spec when `count ≤ max` (`requires = counter::within`), and
`strategy = crate::inputs` draws such counters for the tests.

Next: [16-opaque](../16-opaque).
