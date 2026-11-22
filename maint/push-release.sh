#!/usr/bin/env bash
set -euo pipefail

: "${BRANCH:?}" "${VERSION:?}" "${GITHUB_STEP_SUMMARY:?}"
branch_ref="refs/heads/$BRANCH"
remote_ref="refs/remotes/origin/$BRANCH"
tag="v$VERSION"

git tag -a "$tag" -m "$tag"
for attempt in 1 2 3; do
    if push_output=$(LC_ALL=C git push --porcelain --atomic origin "HEAD:$branch_ref" "refs/tags/$tag" 2>&1); then
        printf '%s\n' "$push_output"
        exit 0
    fi
    printf '%s\n' "$push_output" >&2
    if [[ $attempt == 3 ]] || ! awk -F '\t' -v ref="HEAD:$branch_ref" '
        $1 == "!" {
            if ($2 == ref && $3 ~ /^\[rejected\] \((fetch first|non-fast-forward)\)$/)
                advance = 1
            else if ($3 !~ /^\[(remote )?rejected\] \(atomic push failed\)$/)
                other = 1
        }
        END { exit !(advance && !other) }
    ' <<< "$push_output"; then
        exit 1
    fi

    base=$(git rev-parse HEAD^)
    git fetch --no-tags origin "$branch_ref:$remote_ref"
    if ! git merge-base --is-ancestor "$base" "$remote_ref"; then
        echo "The remote branch no longer contains the release base $base." >&2
        exit 1
    fi

    advance_count=$(git rev-list --count "$base..$remote_ref")
    {
        printf '### Release push retry %s\n\n' "$attempt"
        printf '%s advanced by %s commit(s).\n\n' "$BRANCH" "$advance_count"
        git log --format='- %h %s' "$base..$remote_ref"
        printf '\n'
    } >> "$GITHUB_STEP_SUMMARY"
    if ! git rebase --reapply-cherry-picks --empty=keep --onto "$remote_ref" "$base"; then
        echo "The release commit could not be rebased onto $remote_ref." >&2
        git rebase --abort
        exit 1
    fi
    git tag -fa "$tag" -m "$tag"
done
