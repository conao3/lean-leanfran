# Generate from `leanfran.toml`

`leanfran generate` compiles the modules of your Lake packages to every language you list in `leanfran.toml`. One command replaces a `leanfran --lang <language> module generate` command per module: it builds the packages, binds the types that the generated modules share, and writes the files.

```sh
leanfran generate [--dir <dir>] [--output json|text]
```

`--dir` is the directory of `leanfran.toml` (default: the working directory). The paths in the file are relative to it. `lake` comes from `$LAKE`, then `PATH`.

## The file

Each `[[generate]]` table compiles modules of one Lake package to one language and one directory.

```toml
[[generate]]
lang = "rust"
lake-dir = "lean"
out-dir = "src/gen"
path = "crate::generated"
modules = ["Shop.Cart", "Shop.Order"]

[generate.bind]
"Shop.Money" = "::money::generated::shop_money"

[[generate]]
lang = "python"
lake-dir = "lean"
out-dir = "python/shop/gen"
path = "shop.gen"
modules = [
  { name = "Shop.Cart", as = "cart" },
  { name = "Shop.Order", as = "order", bind = { "Shop.Money" = "money.gen.shop_money" } },
]
```

| Key | Required | Meaning |
|---|---|---|
| `lang` | yes | `rust`, `python` or `go` |
| `lake-dir` | yes | The Lake package that holds the modules |
| `out-dir` | yes | The directory of the generated code |
| `path` | yes | How the language names `out-dir`: a Rust module path, a Python package, a Go import path |
| `modules` | yes | The modules to compile: a module name, a glob, or a table |
| `bind` | no | Types defined outside the table: a Lean namespace and the path of its types in the language |

An entry of `modules` is one of:

- a module name, `"Shop.Cart"`;
- a glob in Lake's notation: `"Shop.*"` is `Shop` and every module below it, `"Shop.+"` is every module below it. A glob matches the modules that `lake build` built in the package;
- a table `{ name = "Shop.Cart", as = "cart", bind = { ... } }`. `as` names the generated code, and `bind` applies to this module only.

## Names and files

| Language | Default name of a module | Files | Path of the module's types |
|---|---|---|---|
| Rust | The module name in snake case, `Shop.Cart` → `shop_cart` | `<out-dir>/<name>.rs` and `<out-dir>/mod.rs`, which declares every module of the table | `<path>::<name>` |
| Python | The same as Rust | `<out-dir>/<name>.py` | `<path>.<name>` |
| Go | The last component in lower case, `Shop.Cart` → `cart` | The package `<name>` in `<out-dir>/<name>/` | `<path>/<name>` |

## Shared types

A type is generated once, in the module of its namespace. Every other module of the same table uses that definition. For each module, `leanfran generate` binds these namespaces, a later line replacing an earlier one:

1. the other modules of its table, each to its path from the table above;
2. the `bind` of the table;
3. the `bind` of the module.

A namespace that is a prefix of the module's own name is left out: the module `Shop.Cart.Item` generates the types of `Shop.Cart` that it uses again. Where two namespaces match a type, the longer one wins.

The files are byte for byte those of the `module generate` commands with the same bindings, so you can move a project to `leanfran.toml` one table at a time and compare the output.

## Exit codes

`0` success; `252` a missing or invalid `leanfran.toml`, or invalid parameters; `254` a module that cannot be converted; `255` other errors, such as a failed `lake build`.
