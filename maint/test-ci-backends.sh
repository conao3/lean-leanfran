#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

check() {
    local expected=$1 actual
    shift
    actual=$(printf '%s\0' "$@" | bash maint/ci-backends.sh)
    if [[ $actual != "$expected" ]]; then
        printf 'Expected %s, got %s for [%s]\n' "$expected" "$actual" "$*" >&2
        exit 1
    fi
}

all='["Rust","Python","TypeScript","Clojure","PHP","Go","C"]'
test "$(bash maint/ci-backends.sh --all)" = "$all"
test "$(bash maint/ci-backends.sh </dev/null)" = '[]'
check '["Rust"]' langs/Rust/crates/example.rs
check '["Python","Clojure"]' langs/Python/src/fixture.py maint/Clojure/test-diff.sh
check '["C"]' langs/C/support/leanfran.c
check '["Go","C"]' langs/Go/LeanGo/Emit.lean
check '["PHP","Go"]' langs/PHP/LeanPhp/RuntimeExterns.lean
check '["TypeScript","Go"]' $'langs/TypeScript/file with\nnewline.ts'
check "$all" langs/Python/src/fixture.py flake.lock
check "$all" langs/Rust/Cargo.toml
check '["C"]' docs/c-guide.md
check '["Rust"]' docs/rust-guide.md langs/Rust/crates/example.rs
check "$all" docs/add-language.md
check "$all" maint/new-backend/test.sh
echo "ci-backends-test: selection, cross-backend inputs and full-check fallback passed"
