# inventory

Stock records with a struct, enums and a `BTreeMap`.

- [`src/item.rs`](src/item.rs): `Item` (with the enum `Kind`) and `Event` (an enum with
  fields) derive `leanfran::Model`, so the specs take and return them: the Lean types
  `inventory.item.Item` and `inventory.item.Event` that Aeneas generates become these Rust
  types in the generated specs. `apply` refines the spec `items.apply` and keeps the id and
  the kind (`ensures(same_id = ..)`); both are proved, and `items::apply` runs the Rust
  `apply` (csimp).
- [`src/stock.rs`](src/stock.rs): `quantity` reads a `BTreeMap`. Aeneas has no model of
  `BTreeMap`: [`lean/ExternalTypes.lean`](lean/ExternalTypes.lean) defines it as a list of
  entries and [`lean/External.lean`](lean/External.lean) defines `BTreeMap.get`, from the
  templates `extract` writes. `quantity` has a model and no obligations (`#[leanfran::model]`).
- [`src/spec.rs`](src/spec.rs): the specs, importing the model's types
  (`LeanRustGen.Model.inventory.Types`).

```
make test      # the tests, from the committed caches (no Lean)
make verify    # cargo leanfran extract and check again (Charon, Aeneas, Mathlib)
```
