#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! ${1-} =~ ^[01]\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo 'usage: maint/Go/bump-version.sh <0.X.Y or 1.X.Y>' >&2
    exit 2
fi

cd "$(dirname "$0")/../../langs/Go"
lean_pattern='^def version : String := "[0-9]+\.[0-9]+\.[0-9]+"$'
go_pattern='^const Version = "[0-9]+\.[0-9]+\.[0-9]+"$'
if ! grep -Eq "$lean_pattern" LeanGo/Cli.lean || ! grep -Eq "$go_pattern" leanfran.go; then
    echo 'bump-version.sh: release version declaration missing from LeanGo/Cli.lean or leanfran.go' >&2
    exit 1
fi
sed -Ei "s/$lean_pattern/def version : String := \"$1\"/" LeanGo/Cli.lean
sed -Ei "s/$go_pattern/const Version = \"$1\"/" leanfran.go

git ls-files -z -- 'samples/*/go.mod' 'testdata/*/go.mod' |
    while IFS= read -r -d '' manifest; do
        go mod edit -modfile="$manifest" -require="github.com/conao3/leanfran-go@v$1"
    done

lake --dir ../.. build leanfran
export LEANFRAN_CLI="$PWD/../../.lake/build/bin/leanfran"
for sample in samples/verified-clamp samples/verified-nibble; do
    (cd "$sample" && go tool leanfran check --require proved)
done
