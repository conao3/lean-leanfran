#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ( $# == 1 && ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ) ]]; then
    echo 'usage: maint/C/test-publish.sh [vX.Y.Z]' >&2
    exit 2
fi

root=$(cd "$(dirname "$0")/../.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT

if [[ $# == 1 ]]; then
    tag=$1
    remote=https://github.com/conao3/lean-leanfran.git
    flake="github:conao3/lean-leanfran/$tag"
else
    source="$temp/source"
    git clone --quiet --no-local --depth 1 "$root" "$source"
    git -C "$root" diff --binary HEAD -- | git -C "$source" apply --allow-empty
    version=$("$source/maint/next-version.sh" patch)
    "$source/maint/set-version.sh" "$version" C
    git -C "$source" -c user.name='C publish check' -c user.email='c-publish@example.invalid' \
        -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet -am "Test C release v$version"
    tag="v$version"
    git -C "$source" tag --no-sign "$tag"
    remote="file://$source"
    flake="git+$remote?ref=refs/tags/$tag"
fi

checkout="$temp/checkout"
version=${tag#v}
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$remote" "$checkout"
grep -Fx "version = \"$version\"" "$checkout/langs/C/lakefile.toml"

mkdir "$temp/consumer"
cp "$checkout/lean-toolchain" "$temp/consumer/"
cp -R "$checkout/langs/C/tests" "$temp/consumer/"

check_consumer() (
    local compiler=$1 out="$temp/$2" flags
    cd "$temp/consumer/tests/cases"
    "$compiler" generate --module-name Examples.PublicApi --out-dir "$out"
    "$compiler" build --out-dir "$out"
    grep -Fx "#define LEANFRAN_VERSION \"$version\"" "$out/leanfran.h"
    flags=$(pkg-config --cflags --libs "$out/public_api.pc")
    eval 'cc -std=c11 ../link/main.c -o "$out/consumer" '"$flags"
    "$out/consumer"
    printf 'C consumer passed for %s via %s\n' "$tag" "$2"
)

nix profile install --profile "$temp/profile" "$flake#c"
check_consumer "$temp/profile/bin/leanfran-c" nix

(cd "$checkout/langs/C" && lake build leanfran-c)
check_consumer "$checkout/langs/C/.lake/build/bin/leanfran-c" lake
