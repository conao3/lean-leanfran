#!/usr/bin/env bash
set -euo pipefail

push_release="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/push-release.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null
export BRANCH=master VERSION=1.2.3
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

for scenario in unchanged advance-1 advance-3 conflict existing-tag; do
    mkdir "$tmp/$scenario"
    cd "$tmp/$scenario"
    git init -q --bare --initial-branch=master remote
    git init -q --initial-branch=master writer
    git -C writer remote add origin ../remote
    echo old > writer/version
    git -C writer add version
    git -C writer commit -qm base
    git -C writer push -q origin master
    git clone -q --depth=1 "file://$PWD/remote" release
    echo "$VERSION" > release/version
    git -C release commit -qam "release v$VERSION"

    case $scenario in
        advance-*)
            for ((i = 1; i <= ${scenario#advance-}; i++)); do
                echo "$i" > writer/other
                git -C writer add other
                git -C writer commit -qm "advance $i"
            done
            ;;
        conflict)
            echo conflict > writer/version
            git -C writer commit -qam conflict
            ;;
        existing-tag)
            git -C writer tag -a "v$VERSION" -m existing
            git -C writer push -q origin "refs/tags/v$VERSION"
            ;;
    esac
    git -C writer push -q origin master
    before=$(git -C remote show-ref)
    export GITHUB_STEP_SUMMARY="$PWD/summary"
    touch "$GITHUB_STEP_SUMMARY"

    case $scenario in
        conflict|existing-tag)
            if (cd release && "$push_release") > output 2>&1; then
                cat output
                echo "$scenario unexpectedly succeeded" >&2
                exit 1
            fi
            [[ $(git -C remote show-ref) == "$before" ]]
            if [[ $scenario == conflict ]]; then
                grep -F 'could not be rebased' output
            else
                grep -F 'already exists' output
                [[ ! -s $GITHUB_STEP_SUMMARY ]]
            fi
            echo "$scenario: failed as expected and remote refs are unchanged"
            ;;
        *)
            (cd release && "$push_release") > output 2>&1 || { cat output; exit 1; }
            [[ $(git -C remote rev-parse "v$VERSION^{}") == "$(git -C remote rev-parse master)" ]]
            [[ $(git -C remote rev-parse master^) == "$(git -C writer rev-parse master)" ]]
            [[ $(git -C remote show master:version) == "$VERSION" ]]
            if [[ $scenario == advance-* ]]; then
                grep -F "advanced by ${scenario#advance-} commit(s)" "$GITHUB_STEP_SUMMARY"
                for ((i = 1; i <= ${scenario#advance-}; i++)); do
                    grep -F "advance $i" "$GITHUB_STEP_SUMMARY"
                done
            else
                [[ ! -s $GITHUB_STEP_SUMMARY ]]
            fi
            echo "$scenario: release commit and tag pushed"
            ;;
    esac
done
