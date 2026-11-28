#!/usr/bin/env bash
set -euo pipefail

leanfran=$(realpath "${1:?usage: maint/test-generate.sh <path to leanfran> <rust|python|go|typescript|php|clojure|c>}")
lang=${2:?usage: maint/test-generate.sh <path to leanfran> <rust|python|go|typescript|php|clojure|c>}
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
    rust|python|go|typescript|php|clojure|c) ;;
    *) fail "unknown language: $lang" ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$fixtures/"*.lean "$fixtures/"{lakefile.toml,lake-manifest.json,lean-toolchain} "$work/"
cp -R "$fixtures/Shapes" "$fixtures/$lang" "$work/"
if [[ $lang == php ]]; then
    cp "$fixtures/php/Inheritance.lean" "$work/"
fi
cd "$work"

expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "ruby"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\n' > leanfran.toml
expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\nmodules = ["A"]\n' > leanfran.toml
expect_status 252 "$leanfran" generate
printf '[[generate]]\nlang = "rust"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["A"]\nmodule = "A"\n' > leanfran.toml
expect_status 252 "$leanfran" generate
if [[ $lang == clojure ]]; then
    printf '[[generate]]\nlang = "clojure"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = ["Choice"]\nbind = { "Choice" = "q" }\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
    printf '[[generate]]\nlang = "clojure"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = [{ name = "Choice", bind = { "Choice" = "q" } }]\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
    printf '[[generate]]\nlang = "clojure"\nlake-dir = "."\nout-dir = "out"\npath = "p"\nmodules = [{ name = "Choice", as = "1st" }]\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
fi
if [[ $lang == c ]]; then
    printf '[[generate]]\nlang = "c"\nlake-dir = "."\nout-dir = "out"\nmodules = ["Choice"]\nbind = { "Choice" = "q" }\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
    printf '[[generate]]\nlang = "c"\nlake-dir = "."\nout-dir = "out"\nmodules = [{ name = "Choice", bind = { "Choice" = "q" } }]\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
    printf '[[generate]]\nlang = "c"\nlake-dir = "."\nout-dir = "out"\nmodules = [{ name = "Choice", as = "lf" }]\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
    printf '[[generate]]\nlang = "c"\nlake-dir = "."\nout-dir = "out"\nmodules = ["Choice", { name = "Settings", as = "Choice" }]\n' > leanfran.toml
    expect_status 252 "$leanfran" generate
fi

cp "$lang/leanfran.toml" leanfran.toml
status=0
"$leanfran" generate --output json > summary.json 2> generate.err || status=$?
cat generate.err >&2
[[ $status == 0 ]] || fail "leanfran generate exited with status $status"
modules=$(grep -oE '"module":"[^"]+"' summary.json | cut -d '"' -f 4 | paste -sd ' ' -)
expected='Choice Settings Report Shapes.Area Shapes Choice'
if [[ $lang == rust ]]; then
    expected='Choice Settings Report Shapes Shapes.Area Choice'
elif [[ $lang == php ]]; then
    expected="$expected Inheritance"
fi
[[ $modules == "$expected" ]] || fail "expected summary order '$expected', found '$modules'"
if [[ $lang == c ]]; then
    grep -Fq "skipping 'Shapes.Unsupported.run'" generate.err || fail 'unsupported declaration missing from the warnings'
elif [[ $lang != clojure ]]; then
    grep -Fq '"name":"Shapes.Unsupported"' summary.json || fail 'unsupported declared type missing from skipped'
fi

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
    php)
        cd php
        find generated external -type f -name '*.php' -exec php -l {} +
        php check.php "$root/langs/PHP/vendor/autoload.php"
        ;;
    clojure)
        "$leanfran" --lang clojure project generate --lake-dir . --namespace-prefix generated --output-dir compare \
            --modules Report Shapes.Area Shapes > /dev/null
        for file in generated/report.clj generated/shapes.clj generated/shapes/area.clj; do
            diff "compare/$file" "clojure/src/$file" || fail "$file differs from project generate"
        done
        cd clojure
        cat > deps.edn <<DEPS
{:paths ["src" "."]
 :deps {org.clojure/clojure {:mvn/version "1.12.7"}
        io.github.conao3/leanfran {:local/root "$root/langs/Clojure"}}}
DEPS
        clojure -M -e "(require 'check)"
        ;;
    c)
        grep -Fq 'struct LF_LEAN("Shapes.Point") area_shapes_point' c/generated/area/area.h ||
            fail 'area.h does not define its Shapes.Point'
        grep -Fq 'struct LF_LEAN("Shapes.Packet") report_shapes_packet_shapes_status' c/generated/report/report.h ||
            fail 'report.h does not define its Shapes.Packet Shapes.Status'
        "$leanfran" --lang c generate --module-name Shapes.Area --out-dir compare/area
        diff -r compare/area c/generated/area || fail 'c/generated/area differs from leanfran --lang c generate'
        for dir in c/external/* c/generated/*; do
            "$leanfran" --lang c build --out-dir "$dir" > /dev/null
        done
        "$leanfran" --lang c sync > /dev/null
        "$leanfran" --lang c status
        "$leanfran" generate > /dev/null
        "$leanfran" --lang c status
        make -C c > /dev/null
        [[ $(c/main) == 'total=12 status=ready enabled=1 level=3' ]] || fail "c/main printed '$(c/main)'"
        [[ $(c/flags) == 'flags enabled=1' ]] || fail "c/flags printed '$(c/flags)'"
        [[ $(c/app) == 'area=12 doubled=24' ]] || fail "c/app printed '$(c/app)'"
        ;;
esac

echo "test-generate.sh: $lang project generation and shared types passed"
