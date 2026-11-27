#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

module=LeanGoTest.ControlComplexity
out=test-out/_generated/complexity
mkdir -p "$out"
lake --dir ../.. build leanfran
lake build "$module"
roots=()
for name in arrayPush arraySet stringPush stringAppend bytePush byteSet; do
    roots+=("$module.$name")
done
../../.lake/build/bin/leanfran --lang go module generate --module-name "$module" --roots "${roots[@]}" \
    --package complexity --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file "$out/complexity.go"
test -z "$(gofmt -l "$out/complexity.go")"
cp testdata/control/complexity/complexity_test.go "$out/"
go vet "./$out"
golangci-lint run "./$out"
CGO_ENABLED=0 go test -count=1 -timeout=2m -v "./$out"
