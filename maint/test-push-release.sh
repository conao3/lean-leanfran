#!/usr/bin/env bash
set -euo pipefail

push_release="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/push-release.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null
export GIT_CONFIG_KEY_1=advice.detachedHead GIT_CONFIG_VALUE_1=false
export BRANCH=master VERSION=1.2.3
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

export TEST_GIT
TEST_GIT=$(command -v git)
mkdir "$tmp/bin"
cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == push && "$*" == *:refs/heads/master* && ! -e ../during-push-done ]]; then
    touch ../during-push-done
    case $DURING_PUSH in
        rewind)
            "$TEST_GIT" -C ../writer push -q origin +HEAD^:refs/heads/master
            ;;
        advance)
            echo during > ../writer/during
            "$TEST_GIT" -C ../writer add during
            "$TEST_GIT" -C ../writer commit -qm "advance during push"
            "$TEST_GIT" -C ../writer push -q origin master
            ;;
    esac
fi
exec "$TEST_GIT" "$@"
EOF
chmod +x "$tmp/bin/git"

fail() {
    cat output
    git -C remote show-ref
    echo "$scenario: $1" >&2
    exit 1
}

for scenario in unchanged advance-1 advance-3 advance-during-push conflict rewind rewind-during-push existing-tag; do
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
    git clone -q "file://$PWD/remote" release
    echo "$VERSION" > release/version
    git -C release commit -qam "release v$VERSION"
    release_commit=$(git -C release rev-parse HEAD)

    case $scenario in
        advance-[0-9]*)
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

    release_path=$PATH
    DURING_PUSH=
    if [[ $scenario == *-during-push ]]; then
        release_path="$tmp/bin:$PATH"
        DURING_PUSH=${scenario%-during-push}
    fi
    export DURING_PUSH
    status=0
    (cd release && PATH="$release_path" && "$push_release" tag && "$push_release" land) > output 2>&1 || status=$?

    kept=$(git -C writer rev-parse master)
    if [[ $scenario == rewind || $scenario == rewind-during-push ]]; then
        kept=$(git -C writer rev-parse master^)
    fi
    git -C remote merge-base --is-ancestor "$kept" master || fail "dropped commits from master"

    case $scenario in
        rewind|existing-tag)
            [[ $status != 0 ]] || fail "unexpectedly succeeded"
            [[ $(git -C remote show-ref) == "$before" ]] || fail "changed remote refs"
            if [[ $scenario == existing-tag ]]; then
                grep -qF 'already exists' output || fail "missing message"
            else
                grep -qF 'Start a new Release run' output || fail "missing message"
            fi
            echo "$scenario: stopped and pushed nothing"
            ;;
        conflict|rewind-during-push)
            [[ $status != 0 ]] || fail "unexpectedly succeeded"
            [[ $(git -C remote rev-parse "v$VERSION^{commit}") == "$release_commit" ]] || fail "tag is not the release commit"
            [[ $(git -C remote rev-parse master) == "$kept" ]] || fail "changed master"
            grep -qF "git merge v$VERSION" output || fail "missing hand fix"
            echo "$scenario: tag pushed, master unchanged, failed with the hand fix"
            ;;
        unchanged)
            [[ $status == 0 ]] || fail "failed"
            [[ $(git -C remote rev-parse "v$VERSION^{commit}") == "$release_commit" ]] || fail "tag is not the release commit"
            [[ $(git -C remote rev-parse master) == "$release_commit" ]] || fail "master is not the release commit"
            echo "$scenario: tag and master point to the release commit"
            ;;
        *)
            [[ $status == 0 ]] || fail "failed"
            [[ $(git -C remote rev-parse "v$VERSION^{commit}") == "$release_commit" ]] || fail "tag is not the release commit"
            [[ $(git -C remote rev-parse master^1) == "$kept" ]] || fail "first parent is not the advanced master"
            [[ $(git -C remote rev-parse master^2) == "$release_commit" ]] || fail "second parent is not the release commit"
            [[ $(git -C remote show master:version) == "$VERSION" ]] || fail "version not merged"
            [[ $(git -C remote log -1 --format=%s master) == "Merge release v$VERSION into master" ]] || fail "merge message"
            echo "$scenario: tag pushed and master merged the release commit"
            ;;
    esac
done
