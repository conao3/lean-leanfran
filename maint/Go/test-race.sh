#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

module=LeanGoTest.ControlRace
out=test-out/_generated/race
mkdir -p "$out"
lake --dir ../.. build leanfran
lake build "$module"
../../.lake/build/bin/leanfran --lang go module generate --module-name "$module" --roots "$module.render" \
    --package race --search-path .lake/build/lib/lean --internal-only --output text \
    --output-file "$out/race.go"
test -z "$(gofmt -l "$out/race.go")"
cp testdata/control/race/race_test.go "$out/"
go vet "./$out"
golangci-lint run "./$out"
CGO_ENABLED=1 go test -race -count=1 -v ./rt "./$out"
