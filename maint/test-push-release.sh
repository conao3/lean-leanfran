#!/usr/bin/env bash
set -euo pipefail

push_release="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/push-release.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null
export BRANCH=master VERSION=1.2.3
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

export TEST_GIT
TEST_GIT=$(command -v git)
mkdir "$tmp/bin"
cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == push ]]; then
    "$TEST_GIT" -C ../writer push -q origin +HEAD^:refs/heads/master
fi
exec "$TEST_GIT" "$@"
EOF
chmod +x "$tmp/bin/git"

for scenario in unchanged advance-1 advance-3 conflict rewind rewind-during-push existing-tag; do
    mkdir "$tmp/$scenario"
    cd "$tmp/$scenario"
    git init -q --bare --initial-branch=master remote
    git init -q --initial-branch=master writer
    git -C writer remote add origin ../remote
    echo old > writer/version
    git -C writer add version
    git -C writer commit -qm base
    git -C writer commit -qm second-base --allow-empty
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
        rewind)
            git -C writer push -q origin +HEAD^:refs/heads/master
            ;;
        existing-tag)
            git -C writer tag -a "v$VERSION" -m existing
            git -C writer push -q origin "refs/tags/v$VERSION"
            ;;
    esac
    if [[ $scenario != rewind ]]; then
        git -C writer push -q origin master
    fi
    before=$(git -C remote show-ref)

    case $scenario in
        advance-*|conflict|rewind|rewind-during-push|existing-tag)
            release_path=$PATH
            if [[ $scenario == rewind-during-push ]]; then
                release_path="$tmp/bin:$PATH"
                before="$(git -C writer rev-parse HEAD^) refs/heads/master"
            fi
            if (cd release && PATH="$release_path" "$push_release") > output 2>&1; then
                cat output
                echo "$scenario unexpectedly succeeded" >&2
                exit 1
            fi
            if [[ $(git -C remote show-ref) != "$before" ]]; then
                cat output
                git -C remote show-ref
                echo "$scenario changed remote refs unexpectedly" >&2
                exit 1
            fi
            if [[ $scenario == existing-tag ]]; then
                grep -F 'already exists' output
            else
                grep -F 'Start a new Release run' output
            fi
            echo "$scenario: failed as expected and remote refs are unchanged"
            ;;
        *)
            (cd release && "$push_release") > output 2>&1 || { cat output; exit 1; }
            [[ $(git -C remote rev-parse "v$VERSION^{}") == "$(git -C remote rev-parse master)" ]]
            [[ $(git -C remote rev-parse master^) == "$(git -C writer rev-parse master)" ]]
            [[ $(git -C remote show master:version) == "$VERSION" ]]
            echo "$scenario: release commit and tag pushed"
            ;;
    esac
done
