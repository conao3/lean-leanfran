#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 <vX.Y.Z>" >&2
    exit 2
fi

metadata=$(mktemp)
trap 'rm -f -- "$metadata"' EXIT
status=$(curl --disable --silent --show-error --max-time 10 --output "$metadata" --write-out '%{http_code}' \
    https://repo.packagist.org/p2/conao3/leanfran.json) || exit 2
case "$status" in
    200) ;;
    404) exit 1 ;;
    *) printf 'Packagist metadata returned HTTP %s\n' "$status" >&2; exit 2 ;;
esac

published=$(jq -er --arg version "${1#v}" '
    .packages["conao3/leanfran"]
    | if type != "array" then error("Missing conao3/leanfran versions in Packagist metadata")
      else any(.[]; (.version | ltrimstr("v")) == $version) | tostring
      end
' "$metadata") || exit 2
test "$published" = true
