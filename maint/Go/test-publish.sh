#!/usr/bin/env bash
set -euo pipefail

maint=$(cd "$(dirname "$0")" && pwd)
source_dir="$maint/../../langs/Go"
temp=$(mktemp -d)
trap 'chmod -R u+w -- "$temp"; rm -rf -- "$temp"' EXIT

export GIT_CONFIG_GLOBAL="$temp/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GOENV=off GOWORK=off GOTOOLCHAIN=local
export GOPATH="$temp/gopath" GOMODCACHE="$temp/modcache"
export GOPROXY=direct GOFLAGS=-mod=mod GONOSUMDB=github.com/conao3/leanfran-go
export HTTPS_PROXY=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 NO_PROXY='' no_proxy=''

module=github.com/conao3/leanfran-go
tag="v$(sed -n 's/^const Version = "\([0-9.]*\)"$/\1/p' "$source_dir/leanfran.go")"
mirror="$temp/mirror.git"
snapshot="$temp/snapshot"
git init --bare --initial-branch=main "$mirror"
git config --global url."file://$mirror".insteadOf "https://$module"
mirror_git() {
    git --git-dir="$mirror" "$@"
}
push_snapshot() {
    bash "$maint/mirror-push.sh" "$tag" "$1" "$mirror"
}

bash "$maint/mirror-snapshot.sh" "$tag" "$snapshot"
wrong_tag=v0.0.0
if [[ $tag == "$wrong_tag" ]]; then
    wrong_tag=v0.0.1
fi
status=0
bash "$maint/mirror-snapshot.sh" "$wrong_tag" "$temp/wrong-version" > "$temp/mismatch.log" 2>&1 || status=$?
test "$status" = 1
grep -F 'must match the Go release versions' "$temp/mismatch.log"
test ! -e "$temp/wrong-version"
push_snapshot "$snapshot"
first_commit=$(mirror_git rev-parse refs/heads/main)
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$tag")"

(
    fixture="$source_dir/samples/embed-range"
    mkdir -p "$temp/fixture/pricing"
    cp -- "$fixture"/{go.mod,main.go} "$temp/fixture/"
    cp -- "$fixture"/pricing/{*.go,leanfran.json} "$temp/fixture/pricing/"
    cd "$temp/fixture"
    go mod edit -dropreplace "$module" -droprequire "$module" -droptool "$module/cmd/leanfran"
    go get "$module@$tag"
    go get -tool "$module/cmd/leanfran@$tag"
    test "$(go list -m -f '{{.Version}}' "$module")" = "$tag"
    CGO_ENABLED=0 go build -o "$temp/app" .
    test "$("$temp/app")" = 3
    go tool leanfran status
)

bash "$maint/mirror-snapshot.sh" "$tag" "$temp/retry"
diff -r -- "$snapshot" "$temp/retry"
push_snapshot "$temp/retry"
test "$first_commit" = "$(mirror_git rev-parse refs/heads/main)"
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$tag")"

printf '\nPublish test conflict\n' >> "$temp/retry/README.md"
status=0
push_snapshot "$temp/retry" > "$temp/conflict.log" 2>&1 || status=$?
cat "$temp/conflict.log"
test "$status" = 1
grep -Fqx "Mirror tag $tag differs from the snapshot" "$temp/conflict.log"
test "$first_commit" = "$(mirror_git rev-parse refs/heads/main)"
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$tag")"
printf 'Go publish checks passed for %s\n' "$tag"
