#!/usr/bin/env bash
set -euo pipefail

leanfran=$(realpath "${1:?usage: maint/test-generate.sh <path to leanfran> <rust|python|go|typescript>}")
lang=${2:?usage: maint/test-generate.sh <path to leanfran> <rust|python|go|typescript>}
root=$(cd "$(dirname "$0")/.." && pwd)
fixtures="$root/tests/generate"

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

case "$lang" in
    rust|python|go|typescript) ;;
    *) fail "unknown language: $lang" ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$fixtures/"*.lean "$fixtures/"{lakefile.toml,lake-manifest.json,lean-toolchain} "$work/"
cp -R "$fixtures/Shapes" "$fixtures/$lang" "$work/"
cd "$work"

expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "ruby"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\n' > leanfran.toml
expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\nmodules = ["A"]\n' > leanfran.toml
expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\nmodule = "A"\n' > leanfran.toml
expect_status 252 "$leanfran" generate

cp "$lang/leanfran.toml" leanfran.toml
"$leanfran" generate --output json > summary.json
modules=$(grep -oE '"module":"[^"]+"' summary.json | cut -d '"' -f 4 | paste -sd ' ' -)
expected='Choice Settings Report Shapes.Area Shapes Choice'
if [[ $lang == rust ]]; then
    expected='Choice Settings Report Shapes Shapes.Area Choice'
fi
[[ $modules == "$expected" ]] || fail "expected summary order '$expected', found '$modules'"
grep -Fq '"name":"Shapes.Unsupported"' summary.json || fail 'unsupported declared type missing from skipped'

case "$lang" in
    rust)
        mv rust/lib.rs rust/src/
        cp "$root/langs/Rust/Cargo.lock" rust/
        cat > rust/Cargo.toml <<MANIFEST
[package]
name = "generate-test"
version = "0.0.0"
edition = "2024"

[dependencies]
leanfran = { path = "$root/langs/Rust/crates/leanfran" }
MANIFEST
        cargo check --manifest-path rust/Cargo.toml --target-dir "$root/langs/Rust/target"
        ;;
    python)
        uv run --project "$root/langs/Python" python python/check.py
        ;;
    go)
        cd go
        go mod init example.com/shapes
        go mod edit -require=github.com/conao3/leanfran-go@v0.0.0 -replace="github.com/conao3/leanfran-go=$root/langs/Go"
        go build ./...
        ;;
    typescript)
        cd typescript
        grep -Fq 'from "../models/Shapes.ts"' generated/Shapes/Area.ts
        grep -Fq 'from "./models/Shapes.ts"' generated/Report.ts
        grep -Fq 'from "../external/Choice.ts"' generated/Report.ts
        grep -Fq 'from "../external/Settings.ts"' generated/Report.ts
        mkdir -p node_modules
        ln -s "$root/langs/TypeScript" node_modules/leanfran
        node "$root/langs/TypeScript/node_modules/vite-plus/bin/vp" pack --no-config --no-dts check.ts
        node dist/check.mjs
        ;;
esac

echo "test-generate.sh: $lang project generation and shared types passed"
