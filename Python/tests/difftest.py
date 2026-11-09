"""Runs a generated module's function the way the native oracle's `main` does.

usage: python tests/difftest.py <module file> <function> (report|io)
"""

import importlib.util
import sys
import threading


def main():
    path, fn, kind = sys.argv[1:4]
    spec = importlib.util.spec_from_file_location("difftest_module", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    f = getattr(mod, fn)
    from lean_python import io

    if kind == "report":
        out = f(0)
        sys.stdout.buffer.write(out + b"\n")
        sys.stdout.flush()
    else:
        sys.exit(io.run_main(f))


threading.stack_size(512 * 1024 * 1024)
t = threading.Thread(target=main)
t.start()
t.join()
