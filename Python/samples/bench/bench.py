"""Time the generated Python against the native C build of the same Lean code.

usage: uv run python samples/bench/bench.py   (after `lake build lean-python oracle-bench LeanPythonTest`)
"""

import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests"))

from conftest import generate

bench = generate("LeanPythonTest.Bench", ROOT / "test-out/bench.py")


def timed(f, *args):
    t = time.perf_counter()
    r = f(*args)
    return r, time.perf_counter() - t


def native(name, n):
    t = time.perf_counter()
    out = subprocess.run(
        [str(ROOT / ".lake/build/bin/oracle-bench"), name, str(n)], check=True, capture_output=True, text=True
    )
    return int(out.stdout), time.perf_counter() - t


print("| workload | n | Python (s) | native C (s) |")
print("|---|---|---|---|")
for name, ns in [
    ("pushLoop", [10_000, 100_000, 1_000_000]),
    ("fib", [100_000]),
    ("naiveFib", [25]),
    ("buildString", [10_000, 100_000]),
    ("sortList", [100_000]),
]:
    for n in ns:
        r, t = timed(getattr(bench, name), n)
        rn, tn = native(name, n)
        assert r == rn, (name, n, r, rn)
        print(f"| {name} | {n} | {t:.3f} | {tn:.3f} |")

from pydantic import BaseModel, TypeAdapter


class PlainItem(BaseModel):
    sku: str
    qty: int
    price: int


items = [bench.Item(sku=f"s{i}", qty=i % 5, price=i) for i in range(10_000)]
raw = [{"sku": f"s{i}", "qty": i % 5, "price": i} for i in range(10_000)]
_, t_call = timed(bench.total, items)
ta = TypeAdapter(list[PlainItem])
_, t_validate = timed(ta.validate_python, raw)
print()
print(
    f"boundary: total(10^4 Items) {t_call:.4f} s; TypeAdapter(list[model]).validate_python(10^4 dicts) {t_validate:.4f} s"
)
