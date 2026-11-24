#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 4 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || -z $2 || -z $3 || -z $4 ]]; then
    echo "Usage: $0 <vX.Y.Z> <snapshot-directory> <mirror-url> <manifest>" >&2
    exit 2
fi

tag=$1
tag_ref="refs/tags/$tag"
snapshot=$(realpath -e -- "$2")
if [[ ! -f $snapshot/$4 ]]; then
    echo "Snapshot is missing $4: $snapshot" >&2
    exit 2
fi

temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
git clone --origin origin --no-checkout -- "$3" "$temp/mirror"
mirror_git() {
    git -C "$snapshot" --git-dir="$temp/mirror/.git" --work-tree="$snapshot" "$@"
}

mirror_git read-tree --empty
mirror_git add --force --all
snapshot_tree=$(mirror_git write-tree)
check_tag_tree() {
    tag_tree=$(mirror_git rev-parse "$tag_ref^{tree}")
    if [[ $tag_tree == "$snapshot_tree" ]]; then
        printf 'Mirror tag %s already matches the snapshot\n' "$tag"
        return 0
    fi
    printf 'Mirror tag %s differs from the snapshot\n' "$tag" >&2
    mirror_git diff --no-ext-diff --binary "$tag_tree" "$snapshot_tree" --
    return 1
}

if mirror_git show-ref --verify --quiet "$tag_ref"; then
    check_tag_tree
    exit 0
fi

mirror_git symbolic-ref HEAD refs/heads/main
if mirror_git show-ref --verify --quiet refs/remotes/origin/main; then
    mirror_git update-ref refs/heads/main refs/remotes/origin/main
fi
mirror_git -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    -c commit.gpgsign=false commit --allow-empty -m "leanfran $tag"
mirror_git tag --no-sign "$tag"
if ! mirror_git push --atomic origin refs/heads/main "$tag_ref"; then
    if mirror_git fetch --no-tags origin "+$tag_ref:$tag_ref"; then
        check_tag_tree
    else
        exit 1
    fi
fi
