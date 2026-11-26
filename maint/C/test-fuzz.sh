#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
backend="$root/langs/C"
compiler="$backend/.lake/build/bin/leanfran-c"
generator="$root/maint/C/fuzz-translate.py"
mkdir -p "$backend/test-out"
scratch=$(mktemp -d "$backend/test-out/fuzz.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
python=$(nix shell --inputs-from "$root" nixpkgs#python3 -c sh -c 'command -v python3')
python() {
    "$python" "$@"
}
export NIX_HARDENING_ENABLE=""

compilers=(clang)
if [[ $(uname -s) == Linux ]]; then
    compilers+=(gcc)
fi

for run in '1 120' '2 120' '3 120 double'; do
    read -r seed functions mode <<<"$run"
    dir="$scratch/seed-$seed"
    mkdir -p "$dir/LeanCLib" "$dir/LeanCModel"
    cp "$backend/lean/LeanCLib/C.lean" "$dir/LeanCLib/C.lean"
    cat >"$dir/lakefile.toml" <<'LAKE'
name = "fuzz"
defaultTargets = ["oracle"]

[[lean_lib]]
name = "LeanCLib"
globs = ["LeanCLib.+"]

[[lean_lib]]
name = "LeanCModel"
globs = ["LeanCModel.+"]

[[lean_exe]]
name = "oracle"
root = "Oracle"
LAKE
    cd "$dir"
    python "$generator" generate "$seed" "$functions" ${mode:+"$mode"}
    "$compiler" translate --block fixture --out LeanCModel/Fixture.lean fixture.c \
        >translated.txt 2>translate.err
    if [[ -s translate.err ]] || [[ $(wc -l <translated.txt) -ne $functions ]]; then
        cat translate.err >&2
        echo "fuzz seed $seed: expected $functions translated functions" >&2
        exit 1
    fi
    lake build oracle >build.log 2>&1 || {
        cat build.log >&2
        exit 1
    }
    .lake/build/bin/oracle >lean.txt
    for cc in "${compilers[@]}"; do
        for opt in -O0 -O2; do
            "$cc" -std=gnu11 -w "$opt" -ffp-contract=off -fsanitize=undefined,float-cast-overflow \
                -fno-sanitize-recover=all driver.c -o driver
            ./driver >"native.txt"
            check=values
            if [[ $cc == clang ]]; then
                check=trap
            fi
            echo "fuzz seed $seed $cc $opt: $(python "$generator" compare lean.txt native.txt "$check")"
        done
    done
done
