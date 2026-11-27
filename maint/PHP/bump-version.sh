#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! ${1-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'usage: maint/PHP/bump-version.sh X.Y.Z' >&2
    exit 2
fi

cd "$(dirname "$0")/../../langs/PHP"
pattern='^def version : String := "[0-9]+\.[0-9]+\.[0-9]+"$'
if ! grep -Eq "$pattern" LeanPhp/Cli.lean; then
    echo 'bump-version.sh: version declaration missing from LeanPhp/Cli.lean' >&2
    exit 1
fi
sed -Ei "s/$pattern/def version : String := \"$1\"/" LeanPhp/Cli.lean
