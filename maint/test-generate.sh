#!/usr/bin/env bash
set -euo pipefail

leanfran=$(realpath "${1:?usage: maint/test-generate.sh <path to leanfran>}")
cd "$(dirname "$0")/../tests/generate"

fail() {
    printf 'test-generate.sh: %s\n' "$*" >&2
    exit 1
}

expect_status() {
    local expected=$1 status=0
    shift
    "$@" >/dev/null 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        fail "$*: expected status $expected, found $status"
    fi
}

rm -rf out expected
"$leanfran" generate > /dev/null

lib=.lake/build/lib/lean
rust() {
    local module=$1 name=$2
    shift 2
    "$leanfran" --lang rust module generate --module-name "$module" --search-path "$lib" \
        --output-file "expected/rust/$name.rs" --output text "$@" > /dev/null
}
python() {
    local module=$1 name=$2
    shift 2
    "$leanfran" --lang python module generate --module-name "$module" --search-path "$lib" \
        --output-file "expected/python/$name.py" --output text "$@" > /dev/null
}
go() {
    local module=$1 name=$2
    shift 2
    "$leanfran" --lang go module generate --module-name "$module" --search-path "$lib" \
        --package "$name" --output-dir "expected/go/$name" --output text "$@" > /dev/null
}

rust Shapes shapes --type-path Report=crate::generated::report
rust Shapes.Area shapes_area --type-path Report=crate::generated::report
rust Report report --type-path Shapes.Area=crate::generated::shapes_area Shapes=crate::generated::shapes
cp out/rust/mod.rs expected/rust/mod.rs
grep -qx 'pub mod report;' out/rust/mod.rs || fail 'out/rust/mod.rs does not declare report'
grep -qx 'pub mod shapes_area;' out/rust/mod.rs || fail 'out/rust/mod.rs does not declare shapes_area'

python Shapes shapes --type-module Report=shapes.gen.report
python Shapes.Area area --type-module Report=shapes.gen.report
python Report report --type-module Shapes.Area=shapes.gen.area Shapes=shapes.points

go Shapes shapes --type-module Report=example.com/shapes/gen/report
go Shapes.Area area --type-module Report=example.com/shapes/gen/report
go Report report --type-module Shapes.Area=example.com/shapes/area --type-module Shapes=example.com/shapes/gen/shapes

diff -r expected out || fail 'leanfran generate differs from the same module generate commands'

config=$(mktemp -d)
trap 'rm -rf "$config"' EXIT
expect_status 252 "$leanfran" generate --dir "$config"
printf '[[generate]]\nlang = "ruby"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\n' > "$config/leanfran.toml"
expect_status 252 "$leanfran" generate --dir "$config"
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\nmodules = ["A"]\n' > "$config/leanfran.toml"
expect_status 252 "$leanfran" generate --dir "$config"
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\nmodule = "A"\n' > "$config/leanfran.toml"
expect_status 252 "$leanfran" generate --dir "$config"

rm -rf out expected
echo 'test-generate.sh: leanfran generate writes the files of the same module generate commands'
