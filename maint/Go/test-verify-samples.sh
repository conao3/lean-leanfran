#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

root=$PWD
cli="$root/../../.lake/build/bin/leanfran"
mkdir -p test-out
out=$(mktemp -d "$root/test-out/verified.XXXXXX")
trap 'rm -rf "$out"' EXIT
for sample in verified-clamp verified-nibble; do
    (cd "samples/$sample" && "$cli" --lang go status)
    dest="$out/$sample"
    mkdir "$dest"
    git ls-files --cached --others --exclude-standard "samples/$sample" |
        while IFS= read -r file; do
            install -D "$file" "$dest/${file#samples/"$sample"/}"
        done
    go mod edit -modfile "$dest/go.mod" -replace "github.com/conao3/leanfran-go=$root"
    (
        cd "$dest"
        "$cli" --lang go check --require proved
        go test -count=1 ./...
        go vet ./...
        test -z "$(gofmt -l .)"
        "$cli" --lang go status
        for file in leanfran.json leanfran_*_gen.go leanfran_model_test.go; do
            cmp "$root/samples/$sample/$file" "$file"
        done
    )
done
(
    cd "$out/verified-nibble"
    sed -i 's/return x \& 15/return x \& 16/' nibble.go
    if go test -count=1 ./... > "$out/mutation.txt" 2>&1; then
        exit 1
    fi
    grep -E 'refines: .*seed=1, input=' "$out/mutation.txt"
)
