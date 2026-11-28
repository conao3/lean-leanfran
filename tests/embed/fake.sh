#!/usr/bin/env bash
set -euo pipefail

command=$1
shift
root=
while [[ $# -gt 0 ]]; do
    case $1 in
        --root) root=$2; shift 2 ;;
        *) shift ;;
    esac
done
fake="$root/fake"
expected=${LEANFRAN_FAKE_GENERATOR_VERSION:-1}
if [[ ${LEANFRAN_GENERATOR_VERSION:-} != "$expected" ]]; then
    echo "compiler generator version \"${LEANFRAN_GENERATOR_VERSION:-}\", expected $expected; install the matching leanfran" >&2
    exit 255
fi
case $command in
    scan)
        if [[ -f $fake/slow ]]; then
            echo "start $$" >>"$LEANFRAN_FAKE_LOG"
            sleep 3
            echo "end $$" >>"$LEANFRAN_FAKE_LOG"
        fi
        if [[ -f $fake/scan.exit ]]; then
            cat "$fake/scan.err" >&2
            exit "$(cat "$fake/scan.exit")"
        fi
        cat "$fake/scan.json"
        ;;
    translate)
        cat >"${LEANFRAN_FAKE_INPUT:-/dev/null}"
        cat "$fake/translate.json"
        ;;
    *)
        echo "unknown command $command" >&2
        exit 252
        ;;
esac
