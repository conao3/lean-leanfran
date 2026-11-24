#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

root=$PWD
export LEANFRAN_GO_CLI="$root/.lake/build/bin/leanfran-go"
mkdir -p test-out
out=$(mktemp -d "$root/test-out/verify.XXXXXX")
trap 'rm -rf "$out"' EXIT
go build -o "$out/leanfran" ./cmd/leanfran
mkdir "$out/tools"
ln -s "$(command -v go)" "$out/tools/go"

for fixture in states translation; do
    cp -R "testdata/verify/$fixture" "$out/$fixture"
    go mod edit -modfile "$out/$fixture/go.mod" -replace "github.com/conao3/leanfran-go=$root"
done

(
    cd "$out/states"
    if "$out/leanfran" check --require proved > "$out/states.txt" 2> "$out/states.err"; then
        exit 1
    fi
    for row in 'Proved proved' 'Sorry sorry' 'Axioms axioms' 'Missing missing'         'Mismatch mismatch' 'Failed failed' 'Unsupported unextracted'; do
        read -r fn state <<< "$row"
        grep -Fx "fixture.test/states.$fn [refines]: $state" "$out/states.txt"
    done
    grep -E 'states.go:[0-9]+:[0-9]+: unsupported' "$out/states.err"
    PATH="$out/tools" "$out/leanfran" status > "$out/fresh.txt"
    grep -Fx "fixture.test/states.Proved [refines]: proved" "$out/fresh.txt"
    sed -i 's/func Proved(n int64) int64 { return n + 1 }/func Proved(n int64) int64 { return n + 2 }/' states.go
    if PATH="$out/tools" "$out/leanfran" status > "$out/stale.txt"; then
        exit 1
    fi
    grep -Fx "fixture.test/states.Proved [refines]: stale" "$out/stale.txt"
)
(
    cd "$out/translation"
    "$out/leanfran" check > "$out/translation.txt"
    test "$(grep -c ': missing$' "$out/translation.txt")" = 22
    go test -count=1 -run '^TestLeanfranModels/(ReadTagged|FlavorOk)$' .
    go test -count=1 ./helper
    go run . > "$out/go.txt"
    workspace=.leanfran/workspace
    cp VerifyOracle.lean "$workspace/"
    cat >> "$workspace/lakefile.toml" <<'LAKE'

[[lean_exe]]
name = "verify-oracle"
root = "VerifyOracle"
LAKE
    (cd "$workspace" && lake build verify-oracle)
    "$workspace/.lake/build/bin/verify-oracle" > "$out/lean.txt"
    diff -u "$out/go.txt" "$out/lean.txt"
    printf 'translation matches Lean C for %s lines\n' "$(wc -l < "$out/go.txt")"
)

(
    cd "$out/translation"
    workspace=$PWD/.leanfran/workspace
    cp "$root/testdata/verify/model/ModelOps.lean" "$workspace/"
    (
        cd "$workspace"
        lake env lean -o .lake/build/lib/lean/ModelOps.olean ModelOps.lean
        lake env "$LEANFRAN_GO_CLI" module generate --module-name ModelOps --package models             --output-dir "$out/translation/models" --output text
    )
    cp "$root/testdata/verify/model/model_test.go" .
    go test -count=1 -run '^TestGoOperations$' .
)
