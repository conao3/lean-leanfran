#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../langs/Go"

root=$PWD
cli="$root/../../.lake/build/bin/leanfran"
mkdir -p test-out
out=$(mktemp -d "$root/test-out/embed-samples.XXXXXX")
trap 'rm -rf "$out"' EXIT
for name in embed-range embed-models; do
    dest="$out/$name"
    mkdir -p "$dest"
    git -C "$root" ls-files "samples/$name" --cached --others --exclude-standard |
        while IFS= read -r file; do
            install -D "$file" "$dest/${file#samples/"$name"/}"
        done
    go mod edit -modfile "$dest/go.mod" -replace "github.com/conao3/leanfran-go=$root"
    (
        cd "$dest"
        "$cli" --lang go status
        "$cli" --lang go sync
        go vet ./...
        test -z "$(gofmt -l .)"
        git -C "$root" ls-files "samples/$name" --cached --others --exclude-standard |
            sed -n '/leanfran_.*_gen.go$/p; /leanfran.json$/p' |
            while IFS= read -r file; do
                cmp "$root/$file" "${file#samples/"$name"/}"
            done
        CGO_ENABLED=0 go build -o "$out/$name.exe" .
        "$out/$name.exe" > "$out/$name.go.out"
    )
done
cat "$out/embed-range/.leanfran/workspace"/LeanGoEmbed/B*.lean > "$out/Oracle.lean"
ns=$(sed -n 's/^namespace //p' "$out/Oracle.lean")
printf '\ndef main : IO Unit := IO.println (%s.width ⟨2, 5, by decide⟩)\n' "$ns" >> "$out/Oracle.lean"
lean --root="$out" -c "$out/Oracle.c" "$out/Oracle.lean"
leanc -o "$out/oracle" "$out/Oracle.c"
"$out/oracle" | diff -u - "$out/embed-range.go.out"
printf '3\n' | diff -u - "$out/embed-models.go.out"
printf 'embed samples pass: range matches C oracle, models shares an order across packages\n'
