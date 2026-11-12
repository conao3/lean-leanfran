"""Running a Lean `main`-like IO action."""

import sys

from lean_python.io_externs import lean_io_result_show_error


def run_main(f):
    """Runs the IR function of an `IO Unit` action as Lean's C `main` does; returns the exit code."""
    r = f()
    sys.stdout.flush()
    if r.tag == 0:
        return 0
    lean_io_result_show_error(r)
    return 1
