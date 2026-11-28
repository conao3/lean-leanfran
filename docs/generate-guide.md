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
| `lang` | yes | `rust`, `python`, `go`, `typescript`, `php`, `clojure`, or `c` |
| `lake-dir` | yes | The Lake package that holds the modules |
| `out-dir` | yes | The directory of the generated code |
| `path` | Rust, Python, Go, PHP, and Clojure | The Rust module path, Python package, Go import path, PHP namespace, or Clojure namespace prefix of `out-dir` |
| `modules` | yes | The modules to compile: a module name, a glob, or a table |
| `bind` | no | Types defined outside the table: a Lean namespace and the path of its types in the language. Clojure and C tables reject it |

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
| TypeScript | Module components separated by slashes, `Shop.Cart` → `Shop/Cart` | `<out-dir>/<name>.ts` | A relative import between the generated files, including the `.ts` extension |
| PHP | The last component, `Shop.Cart` → `Cart` | PSR-4 classes in `<out-dir>/<name>/` | `<path>\<name>` |
| Clojure | Module components in kebab case, separated by dots, `Shop.LineItem` → `shop.line-item` | The namespace `<path>.<name>` in `<out-dir>`, `shop.gen.shop.line-item` → `<out-dir>/shop/gen/shop/line_item.clj` | None: values are maps |
| C | The last component in snake case, `Shop.LineItem` → `line_item`, used as the C prefix | `<name>.h`, `<name>.c`, and the other files of `leanfran --lang c generate` in `<out-dir>/<name>/` | None: each module defines its own types |

For PHP, map the `path` namespace to `out-dir` in Composer's PSR-4 configuration. Use a TOML literal string such as `path = 'App\Lean'` for the namespace. The module name in the table, after applying `as`, determines the subdirectory, namespace suffix, and facade name. Supply an `as` value with a valid PHP identifier when the default name cannot be used.

For Clojure, `out-dir` is a source directory on the classpath, and each module becomes the same namespace and file as `leanfran --lang clojure project generate --namespace-prefix <path>` writes. `as` replaces the name after `path` with dot-separated segments that start with a letter and contain letters, digits, `-`, and `_`. A Clojure namespace passes structures as maps, so it does not define types and does not need `bind`.

For C, each module runs `leanfran --lang c generate --module-name <module> --prefix <name> --out-dir <out-dir>/<name>` in the Lake package. Build its library in the Lake package with `leanfran --lang c build --out-dir <out-dir>/<name>`, as described in the [C guide](c-guide.md#generate-and-build). `as` replaces the prefix with an ASCII identifier that starts with a letter, contains letters, digits, and `_`, and is neither `lf` nor `leanfran`. The names of a table differ in more than letter case. The summary lists the module, the prefix, and the output directory of each module; declarations that the C backend skips appear as warnings on standard error.

A C module does not share types with the other modules of its table. Its header defines a C type with the module's prefix for each Lean type its functions use, so `Shapes.Point` is `area_shapes_point` in the `area` module and `report_shapes_point` in the `report` module. To pass a value from one module to another, encode it with the first module's `<type>_to_json` and decode it with the second module's `<type>_from_json`. A program can link the libraries of several modules of a package, as long as their prefixes differ and it links each Lean module once: two prefixes of the same Lean module define the same Lean initializer. Initialization of several libraries in one program follows [Call the generated API](c-guide.md#call-the-generated-api).

`leanfran.toml` can also hold the keys of `leanfran --lang c sync` (`sources`, `lean-files`, `cflags`, `out-dir`, and `[[require]]`, described in [Embed Lean in C sources](c-guide.md#embed-lean-in-c-sources)). Write them before the first `[[generate]]` table so that TOML reads them as top-level keys. `leanfran generate` reads only the `[[generate]]` tables, and `sync`, `status`, and `check` read only the top-level keys. Keep the `out-dir` of each `[[generate]]` table out of the `sources` patterns, because `sync` scans every file that they match.

## Shared types

A `[[generate]]` table shares one definition of each supported Lean type, except in Clojure and C. The module that declares a structure or inductive type without parameters generates its definition, even when the module has no public functions. A concrete type with parameters, such as `Packet Status`, goes in the first module that needs it. A type declared in a module outside the table follows the same rule.

The compiler generates modules in Lean's import order and uses the path and name of the definition already generated for each type. A module can use types from another module with a parent or child namespace. The module where Lean declares a type determines its ownership, regardless of the type's namespace.

Use `bind` to refer to types defined elsewhere, including types generated by another table. When a type matches a binding, the binding takes priority over the definition in the table. The longest matching namespace wins, and a module's `bind` overrides the table's binding for the same namespace.

TypeScript resolves relative `bind` specifiers from the generated file that imports them. Use module-level `bind` when files in different directories need different relative specifiers.

Within each backend batch, the summary lists modules in their configured order after glob expansion. Unsupported types appear in `skipped` with the reason.

## Exit codes

`0` success; `252` a missing or invalid `leanfran.toml`, or invalid parameters; `254` a module that cannot be converted; `255` other errors, such as a failed `lake build`.
