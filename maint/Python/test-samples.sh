#!/usr/bin/env bash
# Check the committed samples and fixtures with `status`, then sync, run and compare every sample.
# The committed generated modules and leanfran.manifest.json must be up to date.
# usage: maint/Python/test-samples.sh (after `lake build leanfran`)
set -euo pipefail
cd "$(dirname "$0")/../../langs/Python"
python_dir=$PWD
cli=$(cd ../.. && pwd)/.lake/build/bin/leanfran
projects=(samples/*/ samples/steps/*/ tests/embed/)

package_of() {
    basename "$(find "$1" -mindepth 2 -maxdepth 2 -name __init__.py -not -path '*/_lean/*' | head -1 | xargs dirname)"
}

before=$(git status --porcelain --untracked-files=all -- samples tests/embed)
for p in "${projects[@]}"; do
    [ -f "$p/leanfran.manifest.json" ] || continue
    (cd "$p" && uv run --project "$python_dir" "$cli" --lang python status --package "$(package_of .)") || {
        echo "test-samples.sh: status of $p failed" >&2
        exit 1
    }
done
after=$(git status --porcelain --untracked-files=all -- samples tests/embed)
if [ "$before" != "$after" ]; then
    echo "test-samples.sh: status changed the checkout:" >&2
    diff <(echo "$before") <(echo "$after") >&2 || true
    exit 1
fi
for s in samples/*/ samples/steps/*/; do
    [ -f "$s/expected.txt" ] || continue
    LEANFRAN_CLI=$cli samples/run.sh "$s"
done
(cd tests/embed && uv run --project "$python_dir" "$cli" --lang python sync --package pricing 2>/dev/null)
git diff --exit-code -- samples tests/embed
for p in "${projects[@]}"; do
    [ -f "$p/pyproject.toml" ] || continue
    git ls-files --error-unmatch "$p/leanfran.manifest.json" >/dev/null 2>&1 || {
        echo "test-samples.sh: $p/leanfran.manifest.json is not committed" >&2
        exit 1
    }
done
