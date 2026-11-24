#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! ${1-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'usage: maint/C/bump-version.sh X.Y.Z' >&2
    exit 2
fi

cd "$(dirname "$0")/../../langs/C"
manifest_pattern='^version = "[0-9]+\.[0-9]+\.[0-9]+"$'
header_pattern='^#define LEANFRAN_VERSION "[0-9]+\.[0-9]+\.[0-9]+"$'
if ! grep -Eq "$manifest_pattern" lakefile.toml || ! grep -Eq "$header_pattern" support/leanfran.h; then
    echo 'bump-version.sh: release version declaration missing from lakefile.toml or leanfran.h' >&2
    exit 1
fi
sed -E -i.bak "s/$manifest_pattern/version = \"$1\"/" lakefile.toml
sed -E -i.bak "s/$header_pattern/#define LEANFRAN_VERSION \"$1\"/" support/leanfran.h
rm -- lakefile.toml.bak support/leanfran.h.bak
