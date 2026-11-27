#!/usr/bin/env bash
set -euo pipefail

leanfran=${1:?usage: maint/test-compiler.sh <path to leanfran>}

fail() {
    printf 'test-compiler.sh: %s\n' "$*" >&2
    exit 1
}

expect_status() {
    local expected=$1 status=0
    shift
    "$@" >/dev/null 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        fail "$*: expected status $expected, found $status"
    fi
}

version=$("$leanfran" --version)
[[ $version =~ ^leanfran\ [0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--version printed '$version'"

expect_status 252 "$leanfran"
expect_status 252 "$leanfran" module generate
expect_status 252 "$leanfran" --lang
expect_status 252 "$leanfran" --lang ruby module generate

for lang in rust python typescript php go c; do
    first=$("$leanfran" --lang "$lang" --generator-version)
    last=$("$leanfran" --generator-version --lang "$lang")
    [[ $first =~ ^[0-9]+$ ]] || fail "--lang $lang --generator-version printed '$first'"
    [[ $first == "$last" ]] || fail "--lang $lang: '$first' before the command, '$last' after it"
done
expect_status 0 "$leanfran" --lang clojure --version

echo "test-compiler.sh: $version dispatches the 7 languages"
