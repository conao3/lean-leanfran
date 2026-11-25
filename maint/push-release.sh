#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?}" "${VERSION:?}"
branch_ref="refs/heads/$BRANCH"
tag="v$VERSION"
attempts=5

fetch_tip() {
    git fetch -q --no-tags origin "+$branch_ref:refs/remotes/origin/$BRANCH"
    git rev-parse "refs/remotes/origin/$BRANCH"
}

contains() {
    git merge-base --is-ancestor "$1" "$2"
}

hand_fix() {
    printf '%s is tagged and Publish has started, but %s does not contain it. On %s run: git fetch origin tag %s && git merge %s, resolve any conflicts, and push.\n' \
        "$tag" "$BRANCH" "$BRANCH" "$tag" "$tag" >&2
}

push_tag() {
    local base tip
    base=$(git rev-parse HEAD^)
    if [[ -n $(git ls-remote --refs origin "refs/tags/$tag") ]]; then
        printf 'Tag %s already exists on origin. Nothing was pushed.\n' "$tag" >&2
        return 1
    fi
    tip=$(fetch_tip)
    if ! contains "$base" "$tip"; then
        printf '%s at %s no longer contains release base %s. Nothing was pushed. Start a new Release run from the latest %s.\n' \
            "$BRANCH" "$tip" "$base" "$BRANCH" >&2
        return 1
    fi
    git tag -a "$tag" -m "$tag"
    git push -q origin "refs/tags/$tag"
}

land() {
    local release base tip commit conflicts i
    release=$(git rev-parse "refs/tags/$tag^{commit}")
    base=$(git rev-parse "$release^")
    for ((i = 1; i <= attempts; i++)); do
        tip=$(fetch_tip)
        if contains "$release" "$tip"; then
            printf '%s already contains %s.\n' "$BRANCH" "$tag"
            return 0
        fi
        if ! contains "$base" "$tip"; then
            printf '%s at %s no longer contains release base %s.\n' "$BRANCH" "$tip" "$base" >&2
            hand_fix
            return 1
        fi
        if [[ $tip == "$base" ]]; then
            commit=$release
        else
            git checkout -q --detach "$tip"
            if ! git merge -q --no-ff -m "Merge release $tag into $BRANCH" "$release"; then
                conflicts=$(git diff --name-only --diff-filter=U | paste -sd ' ')
                git merge --abort
                printf 'Merging %s into %s conflicts in: %s\n' "$tag" "$BRANCH" "$conflicts" >&2
                hand_fix
                return 1
            fi
            commit=$(git rev-parse HEAD)
        fi
        if git push -q --force-with-lease="$branch_ref:$tip" origin "$commit:$branch_ref"; then
            printf 'Pushed %s to %s.\n' "$commit" "$BRANCH"
            return 0
        fi
    done
    printf '%s kept changing; gave up after %d attempts.\n' "$BRANCH" "$attempts" >&2
    hand_fix
    return 1
}

case ${1-} in
    tag) push_tag ;;
    land) land ;;
    *) echo 'usage: maint/push-release.sh tag|land' >&2; exit 2 ;;
esac
