"""The commands ``scan`` and ``translate`` that ``leanfran --lang python sync|check|status`` runs.

``scan --root <root> --dir <package>`` prints the Lean blocks, models and ``@model`` functions of the
package as JSON; ``translate --root <root>`` reads the request of ``check`` on standard input and
prints the Lean translation of the functions. Neither writes a file. Exit codes: 0 success, 252
invalid parameters, 254 an error in the project (printed as ``<file>:<line>: ...``), 255 an error of
the environment (a compiler of another version).
"""

import importlib.metadata
import json
import os
import sys

from leanfran import embed

USAGE = "usage: python -m leanfran.cli scan --root <root> --dir <package>\n       python -m leanfran.cli translate --root <root>"

INSTALL = "use the leanfran Python package and the leanfran compiler of the same release"


def package_version():
    try:
        return importlib.metadata.version("leanfran")
    except importlib.metadata.PackageNotFoundError:
        return "unknown"


def check_versions(env):
    for name, var, expected in (
        ("release version", "LEANFRAN_VERSION", package_version()),
        ("generator version", "LEANFRAN_GENERATOR_VERSION", embed.GENERATOR_VERSION),
        ("Lean version", "LEANFRAN_LEAN_VERSION", embed.LEAN_VERSION),
    ):
        got = env.get(var)
        if got is None:
            print("leanfran: run leanfran --lang python sync, check or status in the Python project", file=sys.stderr)
            return False
        if got != expected:
            print(f'leanfran: compiler {name} "{got}", expected {expected}; {INSTALL}', file=sys.stderr)
            return False
    return True


def parse(args, names):
    values = {}
    rest = list(args)
    while rest:
        key = rest.pop(0)
        if key not in names or key in values or not rest:
            return None
        values[key] = rest.pop(0)
    return values if set(values) == set(names) else None


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] not in ("scan", "translate"):
        print(USAGE, file=sys.stderr)
        return 252
    command = argv[0]
    values = parse(argv[1:], ("--root", "--dir") if command == "scan" else ("--root",))
    if values is None:
        print(USAGE, file=sys.stderr)
        return 252
    if not check_versions(os.environ):
        return 255
    from leanfran import scan, translation

    out = sys.stdout
    sys.stdout = sys.stderr
    try:
        if command == "scan":
            result = scan.scan(values["--root"], values["--dir"])
        else:
            result = translation.translate_package(values["--root"], json.load(sys.stdin))
    except scan.ScanError as e:
        print(e, file=sys.stderr)
        return e.code
    finally:
        sys.stdout = out
    json.dump(result, out, ensure_ascii=False)
    out.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
