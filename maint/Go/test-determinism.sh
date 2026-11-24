#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

module=LeanGoTest.Vectors
out=test-out/_generated/determinism
lake build leanfran-go "$module"
mkdir -p "$out"

generate() {
    .lake/build/bin/leanfran-go module generate --module-name "$module" --roots "$@" \
        --search-path .lake/build/lib/lean --internal-only --output text --output-file "$out/vectors.go"
}

roots=("$module.run" LeanGoTest.ControlIr.impossible)
generate "${roots[@]}"
cp "$out/vectors.go" "$out/first.go"
generate "${roots[@]}"
cmp "$out/first.go" "$out/vectors.go"
generate "${roots[1]}" "${roots[0]}"
cmp "$out/first.go" "$out/vectors.go"

grep -Fxq 'package vectors' "$out/vectors.go"
sed -nE 's/^(func|var) ([[:alnum:]_]+).*$/\2/p' "$out/vectors.go" | LC_ALL=C sort -cu
test -z "$(gofmt -l "$out/vectors.go")"
go vet "$out/vectors.go"
printf '%s\n' 'determinism: repeated and reordered roots produce identical Go source'
