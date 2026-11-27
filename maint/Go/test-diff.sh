#!/usr/bin/env bash
set -euo pipefail
export LEAN_BACKTRACE=0
cd "$(dirname "$0")/../../langs/Go"

lake --dir ../.. build leanfran
lake build oracle LeanGoTest.Unsupported
mkdir -p test-out/_generated

compiler=../../.lake/build/bin/leanfran
generate() {
    "$compiler" --lang go module generate --search-path .lake/build/lib/lean --internal-only "$@"
}

generate --module-name LeanGoTest.OracleMain --roots main LeanGoTest.ControlIr.impossible \
    --main main --output text --output-file test-out/_generated/vectors/main.go

package=test-out/_generated/vectors/main.go
formatted="$(gofmt -l "$package")"
test -z "$formatted"
go vet "$package"
CGO_ENABLED=0 go build -o test-out/vectors-go "$package"

compare() {
    local mode=$1 expected=$2
    local native_status=0 go_status=0
    local prefix="test-out/diff-$mode"
    .lake/build/bin/oracle "$mode" > "$prefix.c.out" 2> "$prefix.c.err" || native_status=$?
    test-out/vectors-go "$mode" > "$prefix.go.out" 2> "$prefix.go.err" || go_status=$?
    diff -u "$prefix.c.out" "$prefix.go.out"
    diff -u "$prefix.c.err" "$prefix.go.err"
    if [[ "$native_status" != "$expected" || "$go_status" != "$native_status" ]]; then
        echo "diff-test $mode: expected status $expected, got C=$native_status Go=$go_status" >&2
        return 1
    fi
    printf 'diff-test %s: stdout, stderr, and exit %s match\n' "$mode" "$go_status"
}

compare probe 0
compare fail 1
compare status 23

cat > test-out/jobs.json <<'JSON'
[
  {"module":"LeanGoTest.Vectors","roots":["LeanGoTest.Vectors.sumTo"],"package":"sum","output_file":"test-out/_generated/sum/sum.go"},
  {"module":"LeanGoTest.Vectors","namespace":"LeanGoTest.Vectors.updateString","output_file":"test-out/_generated/strings/strings.go"}
]
JSON
generate --batch test-out/jobs.json
for package in test-out/_generated/sum/sum.go test-out/_generated/strings/strings.go; do
    formatted="$(gofmt -l "$package")"
    test -z "$formatted"
    go vet "$package"
    CGO_ENABLED=0 go build "$package"
done
mkdir -p test-out/_generated/host
cat > test-out/_generated/host/main.go <<'GO'
package main

import (
    "fmt"

    "github.com/conao3/leanfran-go/rt"
    "github.com/conao3/leanfran-go/test-out/_generated/sum"
)

func main() {
    fmt.Println(rt.NatString(sum.L_LeanGoTest_Vectors_sumTo(rt.NatFromUint64(1000000), rt.NatFromUint64(0))))
}
GO
gofmt -w test-out/_generated/host/main.go
CGO_ENABLED=0 go build -o test-out/sum-host test-out/_generated/host/main.go
test "$(test-out/sum-host)" = 500000500000
test "$("$compiler" --lang go --generator-version)" = "$(awk '/^const GeneratorVersion = / { print $NF }' leanfran.go)"

status=0
generate --module-name LeanGoTest.Unsupported --output text \
    > test-out/unsupported.out 2> test-out/unsupported.err || status=$?
if [[ "$status" != 254 || -s test-out/unsupported.out ]]; then
    cat test-out/unsupported.err >&2
    echo "Expected status 254 and no Go source for missing externs, got $status" >&2
    exit 1
fi
cat test-out/unsupported.err
grep -q 'lean_go_missing_alpha' test-out/unsupported.err
grep -q 'lean_go_missing_beta' test-out/unsupported.err

status=0
generate --module-name LeanGoTest.Vectors --package switch \
    > test-out/invalid.out 2> test-out/invalid.err || status=$?
test "$status" = 252
test ! -s test-out/invalid.out
grep -q 'invalid Go package name: switch' test-out/invalid.err
