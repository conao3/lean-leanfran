#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! ${1-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'usage: maint/PHP/bump-version.sh X.Y.Z' >&2
    exit 2
fi

cd "$(dirname "$0")/../../langs/PHP"
pattern='^def version : String := "[0-9]+\.[0-9]+\.[0-9]+"$'
php_pattern="^    public const VERSION = '[0-9]+\.[0-9]+\.[0-9]+';$"
if ! grep -Eq "$pattern" LeanPhp/Cli.lean || ! grep -Eq "$php_pattern" src/Lean.php; then
    echo 'bump-version.sh: version declaration missing from LeanPhp/Cli.lean or src/Lean.php' >&2
    exit 1
fi
sed -Ei "s/$pattern/def version : String := \"$1\"/" LeanPhp/Cli.lean
sed -Ei "s/$php_pattern/    public const VERSION = '$1';/" src/Lean.php
