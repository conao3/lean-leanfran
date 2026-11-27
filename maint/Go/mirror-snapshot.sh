#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ! $1 =~ ^v[01]\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ || -z $2 ]]; then
    echo "Usage: $0 <v0.X.Y or v1.X.Y> <output-directory>" >&2
    exit 2
fi

tag=$1
output=$(realpath -m -- "$2")
cd "$(dirname "$0")/../.."

lean_version=$(sed -n 's/^def version : String := "\([0-9.]*\)"$/\1/p' langs/Go/LeanGo/Cli.lean)
go_version=$(sed -n 's/^const Version = "\([0-9.]*\)"$/\1/p' langs/Go/leanfran.go)
if [[ $lean_version != "$go_version" || $tag != "v$lean_version" ]]; then
    printf 'Tag %s must match the Go release versions in LeanGo/Cli.lean (%s) and leanfran.go (%s)\n' \
        "$tag" "$lean_version" "$go_version" >&2
    exit 1
fi

mkdir -p -- "$(dirname "$output")"
snapshot=$(mktemp -d "$(dirname "$output")/.leanfran-go.XXXXXXXX")
trap 'rm -rf -- "$snapshot"' EXIT

git ls-files -z -- langs/Go/go.mod ':(glob)langs/Go/*.go' \
    langs/Go/rt langs/Go/schema langs/Go/cmd/leanfran langs/Go/internal \
    langs/Go/leanfrantest langs/Go/lean ':(exclude,glob)langs/Go/**/*_test.go' |
    while IFS= read -r -d '' file; do
        install -D -m 644 -- "$file" "$snapshot/${file#langs/Go/}"
    done

cp -- LICENSE "$snapshot/"
{
    printf '# leanfran for Go\n\n'
    printf 'This repository mirrors the Go module from [conao3/lean-leanfran](https://github.com/conao3/lean-leanfran), where development, issues, and pull requests live.\n\n'
    tail -n +3 langs/Go/README.md
} > "$snapshot/README.md"

(
    cd "$snapshot"
    module=$(GOWORK=off GOPROXY=off go list -m)
    if [[ $module != github.com/conao3/leanfran-go ]]; then
        printf 'Unexpected Go module path: %s\n' "$module" >&2
        exit 1
    fi
)

mv -T -- "$snapshot" "$output"
printf 'Prepared Go mirror snapshot for %s\n' "$tag"
