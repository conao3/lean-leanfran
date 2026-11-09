"""``lean-py``: the command line of the Python package.

usage: lean-py sync --package <dir> [--lean-python <path>]
"""

import argparse
import os
import sys

USAGE = """usage: lean-py <command> [parameters]

commands:
  sync   Check the Lean blocks of a package and generate their Python modules

lean-py sync
  --package <dir>        The Python package (the directory with __init__.py) (required)
  --lean-python <path>   The Lean CLI (default: $LEAN_PYTHON_CLI, then `lean-python` on PATH)

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"""


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("help", "--help", "-h"):
        print(USAGE, end="")
        return 0
    if argv[0] != "sync":
        print(f"lean-py: unknown command {argv[0]!r} (see `lean-py help`)", file=sys.stderr)
        return 252
    p = argparse.ArgumentParser(prog="lean-py sync", add_help=False, exit_on_error=False)
    p.add_argument("--package", required=True)
    p.add_argument("--lean-python")
    try:
        args = p.parse_args(argv[1:])
    except (argparse.ArgumentError, SystemExit) as e:
        print(f"lean-py: {e}", file=sys.stderr)
        return 252
    from lean_python import sync

    try:
        sync.sync_package(args.package, cli=args.lean_python or os.environ.get("LEAN_PYTHON_CLI"))
    except sync.SyncError as e:
        print(f"lean-py: {e}", file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main())
