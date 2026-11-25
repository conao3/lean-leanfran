#!/usr/bin/env bash
# Keep the dev shells' store paths that cache.nixos.org lacks in a directory for CI.
#   ci-nix-cache.sh save DIR SHELL...     export the missing paths of the shells into DIR
#   ci-nix-cache.sh restore DIR SHELL...  realise the shells, importing the paths in DIR
# Paths over 500 MB (unpacked Rust toolchain parts) stay out of DIR: DIR/prebuild lists
# their derivations, and restore builds them, and substitutes DIR/substitute from
# cache.nixos.org, before it imports the paths that refer to them.
set -euo pipefail
[[ $# -ge 3 && ($1 == save || $1 == restore) ]] || {
  echo "usage: ci-nix-cache.sh save|restore DIR SHELL..." >&2
  exit 2
}
mode=$1
dir=$(realpath -m "$2")
shift 2
cd "$(dirname "$0")/.."
system=$(nix eval --raw --impure --expr builtins.currentSystem)
limit=500000000

import_dir() {
  local drv drvs=()
  xargs nix-store --realise < "$dir/substitute" > /dev/null || return 1
  while read -r drv; do
    if [[ -e $drv ]]; then
      drvs+=("$drv")
    fi
  done < "$dir/prebuild"
  if [[ ${#drvs[@]} -gt 0 ]]; then
    nix-store --realise "${drvs[@]}" > /dev/null || return 1
  fi
  zstd -dc "$dir/store.nar.zst" | nix-store --import > /dev/null
}

if [[ $mode == restore ]]; then
  for shell in "$@"; do
    nix path-info --derivation ".#devShells.$system.$shell" > /dev/null
  done
  if [[ -f $dir/store.nar.zst ]] && ! import_dir; then
    echo "ci-nix-cache: could not import $dir; building the shells without it" >&2
  fi
  for shell in "$@"; do
    nix develop ".#$shell" -c true
  done
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
for shell in "$@"; do
  nix develop --profile "$work/profile-$shell" ".#$shell" -c true
done
nix path-info --recursive "$work"/profile-* | sort -u > "$work/closure"
xargs -P 32 -I{} sh -c '
  hash=$(basename "$1" | cut -c1-32)
  code=$(curl -s -o /dev/null -w "%{http_code}" -A "lean-leanfran-ci/1" "https://cache.nixos.org/$hash.narinfo")
  [ "$code" = 200 ] || echo "$1"
' sh {} < "$work/closure" | sort > "$work/missing"
rm -rf -- "$dir"
mkdir -p -- "$dir"
comm -23 "$work/closure" "$work/missing" > "$dir/substitute"
: > "$dir/prebuild"
small=()
if [[ -s $work/missing ]]; then
  while read -r path size; do
    if [[ $size -gt $limit ]]; then
      nix-store --query --deriver "$path" >> "$dir/prebuild"
    else
      small+=("$path")
    fi
  done < <(xargs nix path-info --size < "$work/missing")
fi
if [[ ${#small[@]} -gt 0 ]]; then
  nix-store --export "${small[@]}" | zstd -T0 -q -o "$dir/store.nar.zst"
fi
echo "ci-nix-cache: $(wc -l < "$work/missing") missing paths, ${#small[@]} exported to $dir, $(wc -l < "$dir/prebuild") to build first"
