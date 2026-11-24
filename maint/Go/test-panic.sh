#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"
export LEAN_BACKTRACE=0
unset LEANFRAN_GO_TEST_INIT_FAILURE

lake build leanfran-go
mkdir -p test-out/_generated
tmp=$(mktemp -d "$PWD/test-out/_generated/panic.XXXXXXXX")
trap 'rm -r "$tmp"' EXIT

mkdir -p "$tmp"/{LeanGoTest,library,command}
cp LeanGoTest/Panic.lean "$tmp/LeanGoTest/"
(
    cd "$tmp"
    export LEAN_PATH="$tmp"
    lean -o LeanGoTest/Panic.olean -c LeanGoTest/Panic.c LeanGoTest/Panic.lean
    leanc -O2 -o oracle LeanGoTest/Panic.c
)
generate() {
    .lake/build/bin/leanfran-go module generate --module-name LeanGoTest.Panic \
        --search-path "$tmp" --internal-only "$@"
}
generate --roots main --main main --output text --output-file "$tmp/command/main.go"
generate --roots LeanGoTest.Panic.unreachable LeanGoTest.Panic.unreadableRef \
    LeanGoTest.Panic.increment LeanGoTest.Panic.leanPanic --package fixture \
    --output text --output-file "$tmp/library/fixture.go"
cp testdata/panic/panic_test.go "$tmp/library/"
test -z "$(gofmt -l "$tmp/command/main.go" "$tmp/library/fixture.go")"
go vet "$tmp/command/main.go"
library="./${tmp#"$PWD/"}/library"
go vet "$library"
golangci-lint run "$library"
CGO_ENABLED=0 go build -o "$tmp/main-go" "$tmp/command/main.go"
CGO_ENABLED=0 go test -count=1 "$library"

for mode in main-panic panic io-error; do
    for backend in oracle main-go; do
        status=0
        if [[ $mode == main-panic ]]; then
            "$tmp/$backend" unreachable > "$tmp/$backend.out" 2> "$tmp/$backend.err" || status=$?
        else
            LEANFRAN_GO_TEST_INIT_FAILURE="$mode" "$tmp/$backend" > "$tmp/$backend.out" 2> "$tmp/$backend.err" || status=$?
        fi
        if [[ $status != 1 ]]; then
            cat "$tmp/$backend.out" "$tmp/$backend.err" >&2
            printf '%s %s exited %s, expected 1\n' "$backend" "$mode" "$status" >&2
            exit 1
        fi
    done
    diff -u "$tmp/oracle.out" "$tmp/main-go.out"
    diff -u "$tmp/oracle.err" "$tmp/main-go.err"
    printf '%s: C and Go agree on stdout, stderr, and exit 1\n' "$mode"
done
