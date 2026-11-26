#!/usr/bin/env bash
set -euo pipefail

all='["Rust","Python","TypeScript","Clojure","PHP","Go","C"]'
if [[ ${1:-} == --all ]]; then
    printf '%s\n' "$all"
    exit
fi

declare -A selected=()
while IFS= read -r -d '' path; do
    case "$path" in
        docs/rust-guide.md | docs/rust-development.md) selected[Rust]=1 ;;
        docs/python-guide.md | docs/python-development.md) selected[Python]=1 ;;
        docs/typescript-guide.md | docs/typescript-development.md) selected[TypeScript]=1 ;;
        docs/clojure-guide.md | docs/clojure-development.md) selected[Clojure]=1 ;;
        docs/php-guide.md | docs/php-development.md) selected[PHP]=1 ;;
        docs/go-guide.md | docs/go-development.md) selected[Go]=1 ;;
        docs/c-guide.md | docs/c-development.md) selected[C]=1 ;;
        langs/Rust/Cargo.toml)
            # flake.nix reads the shared release version from this file.
            printf '%s\n' "$all"
            exit
            ;;
        langs/*/* | maint/*/*)
            backend=${path#*/}
            backend=${backend%%/*}
            case "$backend" in
                Rust|Python|TypeScript|Clojure|PHP|Go|C) selected[$backend]=1 ;;
                *) printf '%s\n' "$all"; exit ;;
            esac
            ;;
        *) printf '%s\n' "$all"; exit ;;
    esac
    case "$path" in
        langs/Go/*) selected[C]=1 ;; # C compares schemas with Go.
        langs/PHP/* | langs/TypeScript/*) selected[Go]=1 ;; # Go checks PHP externs and TypeScript schemas.
        langs/Python/LeanPython/RuntimeExterns.lean) selected[PHP]=1 ;; # PHP checks Python extern coverage.
    esac
done

separator=
printf '['
for backend in Rust Python TypeScript Clojure PHP Go C; do
    if [[ ${selected[$backend]:-} ]]; then
        printf '%s"%s"' "$separator" "$backend"
        separator=,
    fi
done
printf ']\n'
