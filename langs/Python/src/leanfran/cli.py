"""The command line of the Python package."""

import argparse
import sys

USAGE = """usage: leanfran --lang python <command> [parameters]

commands:
  sync     Check the Lean blocks of a package and generate their Python modules
  check    Translate the @model functions to Lean and judge the proofs of their obligations
  status   Show the states recorded by `check`, marking functions changed since then (no Lean)

leanfran --lang python sync
  --package <dir>        The Python package (the directory with __init__.py) (required)

leanfran --lang python check
  --package <dir>        as for sync
  --require proved       Exit with 254 unless every obligation is proved

leanfran --lang python status
  --package <dir>        The Python package (required)

exit codes: 0 success, 252 invalid parameters, 254 input that cannot be converted, 255 other errors
"""


class _ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise argparse.ArgumentError(None, message)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("help", "--help", "-h"):
        print(USAGE, end="")
        return 0
    command = argv[0]
    if command not in ("sync", "check", "status"):
        print(f"leanfran: unknown command {command!r} (see `leanfran --lang python help`)", file=sys.stderr)
        return 252
    p = _ArgumentParser(prog=f"leanfran --lang python {command}", exit_on_error=False)
    p.add_argument("--package", required=True, help="Python package directory containing __init__.py")
    p.add_argument(
        "--require",
        choices=["proved"],
        help=argparse.SUPPRESS if command == "sync" else "require all reported obligations to be proved",
    )
    try:
        args = p.parse_args(argv[1:])
    except argparse.ArgumentError as e:
        p.print_usage(sys.stderr)
        print(f"leanfran: {e}", file=sys.stderr)
        return 252
    except SystemExit as e:
        return e.code
    from leanfran import check, sync

    try:
        if command == "sync":
            sync.sync_package(args.package)
            return 0
        if command == "check":
            lock, _ = check.check_package(args.package)
            rows = [(q, label, st) for q, e in sorted(lock.items()) for label, st in e["obligations"].items()]
        else:
            rows = check.status(args.package)
    except sync.SyncError as e:
        print(f"leanfran: {e}", file=sys.stderr)
        return e.code
    for q, label, st in rows:
        print(f"{st:<10} {q} {label}")
    if args.require == "proved" and any(st != "proved" for _, _, st in rows):
        return 254
    return 0


if __name__ == "__main__":
    sys.exit(main())
