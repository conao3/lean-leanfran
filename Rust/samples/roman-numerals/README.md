# roman-numerals

Use Lean code from an ordinary lake project in Rust, without `lean!`.

[`lean/Roman.lean`](lean/Roman.lean) converts between numbers and Roman numerals and proves
that the conversion round-trips for every number below 1000:

```lean
def toRoman (n : Nat) : String := toRomanAux (n + 13) numerals n

def fromRoman (s : String) : Option Nat := ...

theorem roundtrip : ∀ n, n < 1000 → fromRoman (toRoman n) = if n = 0 then none else some n := by
  decide +kernel
```

`leanfran project generate` turns the module into the Rust module
[`src/generated/roman.rs`](src/generated/roman.rs) and [`src/generated/mod.rs`](src/generated/mod.rs),
which are committed. The crate builds with cargo alone; no Lean is needed:

```rust
mod generated;
use generated::roman;

assert_eq!(roman::to_roman(1994u64.into()), "MCMXCIV");
assert_eq!(roman::from_roman("MMXXVI"), Some(2026u64.into()));
assert_eq!(roman::from_roman("hello"), None);
```

The public functions are the module's non-private definitions, named in snake_case
(`toRoman` → `to_roman`); `Option Nat` comes back as `Option<Nat>`.

## Usage

```
$ ../../target/debug/roman-numerals to-roman 1994
MCMXCIV
$ ../../target/debug/roman-numerals from-roman MMXXVI
2026
```

## Regenerating

After changing the Lean code, run inside `nix develop` of the repository root:

```
make generate
```

It runs

```
leanfran project generate --lake-dir lean --output-dir src/generated
```

which checks the proofs with `lake build` and writes a Rust module per Lean module. `make test`
regenerates, fails if the committed modules are out of date, and compares a few calls with
`expected.txt`.
