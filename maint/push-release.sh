#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?}" "${VERSION:?}"
branch_ref="refs/heads/$BRANCH"
base=$(git rev-parse HEAD^)
tag="v$VERSION"

require_release_base() {
    local tip
    tip=$(git ls-remote --refs origin "$branch_ref") || return 1
    tip=${tip%%$'\t'*}
    if [[ $tip != "$base" ]]; then
        printf '%s changed from release base %s to %s. Start a new Release run from the latest %s.\n' \
            "$BRANCH" "$base" "${tip:-<missing>}" "$BRANCH" >&2
        return 1
    fi
}

require_release_base
git tag -a "$tag" -m "$tag"
if ! git push --atomic --force-with-lease="$branch_ref:$base" origin "HEAD:$branch_ref" "refs/tags/$tag"; then
    require_release_base
    exit 1
fi
