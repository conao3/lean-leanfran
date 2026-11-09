"""``lean-py``: the command line of the Python package.

usage: lean-py sync --package <dir> [--lean-python <path>]
"""

import argparse
import os
import sys

USAGE = """usage: lean-py <command> [parameters]

commands:
  sync     Check the Lean blocks of a package and generate their Python modules
  check    Translate the @model functions to Lean and judge the proofs of their obligations
  status   Show the states recorded by `check`, marking functions changed since then (no Lean)

lean-py sync
  --package <dir>        The Python package (the directory with __init__.py) (required)
  --lean-python <path>   The Lean CLI (default: $LEAN_PYTHON_CLI, then `lean-python` on PATH)

lean-py check
  --package <dir>, --lean-python <path>   as for sync
  --require proved       Exit with 254 unless every obligation is proved

lean-py status
  --package <dir>        The Python package (required)

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"""


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("help", "--help", "-h"):
        print(USAGE, end="")
        return 0
    command = argv[0]
    if command not in ("sync", "check", "status"):
        print(f"lean-py: unknown command {command!r} (see `lean-py help`)", file=sys.stderr)
        return 252
    p = argparse.ArgumentParser(prog=f"lean-py {command}", add_help=False, exit_on_error=False)
    p.add_argument("--package", required=True)
    p.add_argument("--lean-python")
    p.add_argument("--require", choices=["proved"])
    try:
        args = p.parse_args(argv[1:])
    except (argparse.ArgumentError, SystemExit) as e:
        print(f"lean-py: {e}", file=sys.stderr)
        return 252
    from lean_python import check, sync

    cli = args.lean_python or os.environ.get("LEAN_PYTHON_CLI")
    try:
        if command == "sync":
            sync.sync_package(args.package, cli=cli)
            return 0
        if command == "check":
            lock, _ = check.check_package(args.package, cli=cli)
            rows = [(q, label, st) for q, e in sorted(lock.items()) for label, st in e["obligations"].items()]
        else:
            rows = check.status(args.package)
    except sync.SyncError as e:
        print(f"lean-py: {e}", file=sys.stderr)
        return e.code
    for q, label, st in rows:
        print(f"{st:<10} {q} {label}")
    if args.require == "proved" and any(st != "proved" for _, _, st in rows):
        return 254
    return 0


if __name__ == "__main__":
    sys.exit(main())
