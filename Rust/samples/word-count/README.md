# word-count

Print the most frequent words of a text. The counting is Lean, in [`src/lib.rs`](src/lib.rs);
the CLI in [`src/main.rs`](src/main.rs) reads standard input and prints.

This sample shows what [`todo-cli`](../todo-cli) does not use:

- **`imports`** brings in Lean modules beyond the core library, here `Std.Data.HashMap`.
- **`do` notation** (`let mut`, `for`) in `frequencies`.
- **`private`** keeps `frequencies` out of the Rust module; its `HashMap` result has no Rust
  type, and the public `topWords` uses it internally.

```rust
leanfran::lean! {
    #[lean(imports = ["Std.Data.HashMap"])]
    pub mod count;
    r#"
    private def frequencies (ws : List String) : Std.HashMap String Nat := Id.run do
      let mut m := {}
      for w in ws do
        m := m.insert w (m.getD w 0 + 1)
      return m

    def topWords (n : Nat) (text : String) : List (String × Nat) := ...

    theorem topWords_at_most (n : Nat) (text : String) : (topWords n text).length ≤ n := by
      simp [topWords]
      omega
    "#
}
```

`topWords` returns `List (String × Nat)`, which Rust receives as `Vec<(String, Nat)>`:

```rust
let top = word_count::count::top_words(2u64.into(), "the cat and the hat");
assert_eq!(top, vec![("the".into(), 2u64.into()), ("and".into(), 1u64.into())]);
```

## Usage

```
$ make run ARGS='--limit 4'
5	the
3	dog
2	fox
2	is
$ ../../target/debug/word-count text list-top-words --limit 2 < sample.txt
5	the
3	dog
```

`--limit` defaults to 10. `make test` compares the output for [`sample.txt`](sample.txt) with
`expected.txt`.
