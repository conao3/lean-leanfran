#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?}" "${VERSION:?}"
branch_ref="refs/heads/$BRANCH"
tag="v$VERSION"
tag_ref="refs/tags/$tag"
attempts=5
release=$(git rev-parse HEAD)
commit=$release
expected=$(git rev-parse HEAD^)

require_new_tag() {
    if [[ -n $(git ls-remote --refs origin "$tag_ref") ]]; then
        printf 'Tag %s already exists on origin. Nothing was pushed. Start a new Release run.\n' "$tag" >&2
        return 1
    fi
}

for ((i = 1; i <= attempts; i++)); do
    require_new_tag
    git tag -f -a "$tag" -m "$tag" "$commit" > /dev/null
    if git push -q --atomic --force-with-lease="$branch_ref:$expected" origin "$commit:$branch_ref" "$tag_ref"; then
        printf 'Pushed %s and %s at %s.\n' "$BRANCH" "$tag" "$commit"
        exit 0
    fi
    git fetch -q --no-tags origin "+$branch_ref:refs/remotes/origin/$BRANCH"
    expected=$(git rev-parse "refs/remotes/origin/$BRANCH")
    git checkout -q --detach "$expected"
    if ! git cherry-pick "$release" > /dev/null 2>&1; then
        conflicts=$(git diff --name-only --diff-filter=U | paste -sd ' ')
        git cherry-pick --abort
        printf 'The version changes of %s conflict with %s at %s in: %s. Nothing was pushed. Start a new Release run.\n' \
            "$tag" "$BRANCH" "$expected" "$conflicts" >&2
        exit 1
    fi
    commit=$(git rev-parse HEAD)
done
printf '%s kept changing; nothing was pushed after %d attempts. Start a new Release run.\n' "$BRANCH" "$attempts" >&2
exit 1
