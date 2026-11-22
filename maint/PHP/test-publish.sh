#!/usr/bin/env bash
set -euo pipefail

maint=$(cd "$(dirname "$0")" && pwd)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
export COMPOSER_HOME="$temp/composer-home"
export COMPOSER_DISABLE_NETWORK=1

mirror="$temp/mirror.git"
snapshot="$temp/snapshot"
first_tag=v0.1.0
second_tag=v0.1.1
git init --bare --initial-branch=main "$mirror"
mirror_git() {
    git --git-dir="$mirror" "$@"
}

bash "$maint/mirror-snapshot.sh" "$first_tag" "$snapshot"
test -x "$snapshot/bin/leanfran"
cmp "$maint/../../langs/PHP/src/lean/LeanPhpLib/Php.lean" "$snapshot/src/lean/LeanPhpLib/Php.lean"
bash "$maint/mirror-push.sh" "$first_tag" "$snapshot" "$mirror"
first_commit=$(mirror_git rev-parse refs/heads/main)
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$first_tag")"
test "$(mirror_git log -1 --format='%an <%ae> %s' main)" = \
    "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com> leanfran $first_tag"
printf '(a) Empty mirror: main and %s point to %s\n' "$first_tag" "$first_commit"

bash "$maint/mirror-snapshot.sh" "$first_tag" "$temp/retry"
diff -r -- "$snapshot" "$temp/retry"
bash "$maint/mirror-push.sh" "$first_tag" "$temp/retry" "$mirror"
test "$first_commit" = "$(mirror_git rev-parse refs/heads/main)"
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$first_tag")"
commit_count=$(mirror_git rev-list --count main)
test "$commit_count" = 1
printf '(b) Identical retry: main still has %s commit\n' "$commit_count"

printf '\nPublish test conflict\n' >> "$temp/retry/README.md"
status=0
bash "$maint/mirror-push.sh" "$first_tag" "$temp/retry" "$mirror" > "$temp/conflict.log" 2>&1 || status=$?
cat "$temp/conflict.log"
test "$status" = 1
grep -Fqx "Mirror tag $first_tag differs from the snapshot" "$temp/conflict.log"
grep -Fqx '+Publish test conflict' "$temp/conflict.log"
test "$first_commit" = "$(mirror_git rev-parse refs/heads/main)"
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$first_tag")"
printf '(c) Conflicting retry: exit %s, main and tag kept at %s\n' "$status" "$first_commit"

bash "$maint/mirror-snapshot.sh" "$second_tag" "$temp/next"
bash "$maint/mirror-push.sh" "$second_tag" "$temp/next" "$mirror"
second_commit=$(mirror_git rev-parse refs/heads/main)
test "$second_commit" = "$(mirror_git rev-parse "refs/tags/$second_tag")"
test "$first_commit" = "$(mirror_git rev-parse 'refs/heads/main^')"
test "$first_commit" = "$(mirror_git rev-parse "refs/tags/$first_tag")"
commit_count=$(mirror_git rev-list --count main)
test "$commit_count" = 2
printf '(d) Next tag %s: main advanced to %s (%s commits)\n' "$second_tag" "$second_commit" "$commit_count"

git -c advice.detachedHead=false clone --branch "$second_tag" -- "$mirror" "$temp/package"
diff -r -x .git -- "$temp/next" "$temp/package"
mkdir "$temp/project"
cd "$temp/project"
cat > composer.json <<EOF
{
    "require": {"conao3/leanfran": "${second_tag#v}"},
    "repositories": [
        {"type": "path", "url": "../package", "options": {"symlink": false}},
        {"packagist.org": false}
    ]
}
EOF
composer install --no-interaction
vendor/bin/leanfran --help | grep -F 'leanfran sync'
result=$(php -r 'require "vendor/autoload.php"; echo Conao3\Leanfran\Runtime\lean_nat_add(19, 23);')
test "$result" = 42
printf '(e) Composer path install: lean_nat_add(19, 23) = %s\n' "$result"
