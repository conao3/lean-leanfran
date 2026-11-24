#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

lake build leanfran-go
out=test-out/samples
source=test-out/_generated/samples
mkdir -p "$out" "$source"
compiler=.lake/build/bin/leanfran-go

lean --root=samples/sum-to -o "$out/SumTo.olean" samples/sum-to/SumTo.lean
"$compiler" module generate --module-name SumTo --roots sumTo --package arith \
    --search-path "$out" --internal-only --output text --output-file "$source/arith.go"
test -z "$(gofmt -l "$source/arith.go")"
go vet "$source/arith.go"
cmp "$source/arith.go" samples/sum-to/arith/arith.go
CGO_ENABLED=0 go build -o "$out/sum-to" ./samples/sum-to
"$out/sum-to" > "$out/sum-to.out"
printf '500000500000\n' | diff -u - "$out/sum-to.out"

lean --root=samples/greet-cli -o "$out/Greeting.olean" samples/greet-cli/Greeting.lean
"$compiler" module generate --module-name Greeting --roots main --main main \
    --search-path "$out" --internal-only --output text --output-file "$source/greeting.go"
test -z "$(gofmt -l "$source/greeting.go")"
go vet "$source/greeting.go"
CGO_ENABLED=0 go build -o "$out/greet-cli" "$source/greeting.go"
"$out/greet-cli" Lean > "$out/greet.out"
printf 'Hello, Lean!\n' | diff -u - "$out/greet.out"
status=0
"$out/greet-cli" > "$out/usage.out" 2> "$out/usage.err" || status=$?
test "$status" = 2
test ! -s "$out/usage.out"
printf 'usage: greet-cli NAME\n' | diff -u - "$out/usage.err"
printf 'samples sum-to and greet-cli pass\n'

lean --root=samples/pricing -o "$out/Pricing.olean" samples/pricing/Pricing.lean
"$compiler" module generate --module-name Pricing --search-path "$out"     --output text --output-dir "$source/pricing"
test -z "$(gofmt -l "$source/pricing" samples/pricing)"
for file in "$source/pricing/"*_gen.go; do
    cmp "$file" "samples/pricing/pricing/${file##*/}"
done
go vet ./samples/pricing/...
CGO_ENABLED=0 go build -o "$out/pricing" ./samples/pricing
"$out/pricing" > "$out/pricing.out"
printf '1800\n{"hi":3,"lo":1}\n' | diff -u - "$out/pricing.out"
printf 'sample pricing passes\n'
