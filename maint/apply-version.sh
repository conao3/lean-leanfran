#!/usr/bin/env bash
# Apply the version patches that the jobs of Release made, one per backend: apply-version.sh
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob
patches=(version-*.patch)
[[ ${#patches[@]} -gt 0 ]] || { echo "apply-version.sh: no version-*.patch" >&2; exit 1; }
applied=0
for patch in "${patches[@]}"; do
  if [[ -s "$patch" ]]; then
    git apply "$patch"
    applied=$((applied + 1))
  fi
  rm "$patch"
done
[[ $applied -gt 0 ]] || { echo "apply-version.sh: every patch is empty" >&2; exit 1; }
