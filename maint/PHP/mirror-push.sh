#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || -z $2 || -z $3 ]]; then
    echo "Usage: $0 <vX.Y.Z> <snapshot-directory> <mirror-url>" >&2
    exit 2
fi

tag=$1
tag_ref="refs/tags/$tag"
snapshot=$(realpath -e -- "$2")
if [[ ! -f $snapshot/composer.json ]]; then
    echo "Snapshot is missing composer.json: $snapshot" >&2
    exit 2
fi

temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
git clone --no-checkout -- "$3" "$temp/mirror"
mirror_git() {
    git -C "$snapshot" --git-dir="$temp/mirror/.git" --work-tree="$snapshot" "$@"
}

mirror_git read-tree --empty
mirror_git add --force --all
snapshot_tree=$(mirror_git write-tree)
if mirror_git show-ref --verify --quiet "$tag_ref"; then
    tag_tree=$(mirror_git rev-parse "$tag_ref^{tree}")
    if [[ $tag_tree == "$snapshot_tree" ]]; then
        printf 'Mirror tag %s already matches the snapshot\n' "$tag"
        exit 0
    fi
    printf 'Mirror tag %s differs from the snapshot\n' "$tag" >&2
    mirror_git diff --no-ext-diff --binary "$tag_tree" "$snapshot_tree" --
    exit 1
fi

mirror_git symbolic-ref HEAD refs/heads/main
if mirror_git show-ref --verify --quiet refs/remotes/origin/main; then
    mirror_git update-ref refs/heads/main refs/remotes/origin/main
fi
mirror_git -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    -c commit.gpgsign=false commit --allow-empty -m "leanfran $tag"
mirror_git tag --no-sign "$tag"
mirror_git push --atomic origin refs/heads/main "$tag_ref"
