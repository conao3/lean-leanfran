# Samples

Each sample is a Python package with Lean blocks (`lean(...)`). `samples/run.sh <dir>` runs
`lean-py sync` on it (checking the proofs and regenerating `<package>/_lean/`) and compares the
output of `python -m <package>` with `expected.txt`. `make samples` runs all of them and checks that
the committed generated modules are up to date.

| sample | shows |
|---|---|
| [word-count](word-count) | strings and lists, a proof by induction |
| [roman-numerals](roman-numerals) | a round-trip theorem checked for every number below 1000 (`decide +kernel`) |
| [todo-cli](todo-cli) | an invariant over a list (`∀ t ∈ items, t.id < nextId`) kept by every operation, JSON storage, tampered JSON rejected |
| [pricing-api](pricing-api) | FastAPI with a user's pydantic model and a Lean inductive type as request body, 422 for invalid input, OpenAPI schema |

`steps/` introduces one feature at a time:

| step | feature |
|---|---|
| [01-functions](steps/01-functions) | functions on `Nat`, `String`, `Bool` |
| [02-theorems](steps/02-theorems) | theorems next to the code |
| [03-structures](steps/03-structures) | structures as pydantic models, a proof field as a validator |
| [04-inductives](steps/04-inductives) | enums, inductive types, JSON, `match` |
| [05-collections](steps/05-collections) | `List`, `Array`, `Option`, loops with in-place updates |
| [06-imports](steps/06-imports) | `imports=[...]` (`Std.HashMap`) |
| [07-io](steps/07-io) | `IO`: files, child processes, `LeanIOError` |
| [08-pydantic-models](steps/08-pydantic-models) | `models=[...]`: a user's model in Lean, its constraints in proofs |
| [09-uses](steps/09-uses) | `uses=[...]`: types shared between blocks |
