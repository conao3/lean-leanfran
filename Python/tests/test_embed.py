"""`lean(...)` blocks: `lean-py sync`, the generated modules, user models, `uses`, and FastAPI."""

import os
import pathlib
import shutil
import subprocess
import sys

import pytest
from conftest import CLI, ROOT


def run(cmd, cwd, **kw):
    env = {**os.environ, "LEAN_PYTHON_CLI": str(CLI), "PYTHONPATH": str(cwd)}
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, check=False, **kw)


@pytest.fixture(scope="module")
def project(tmp_path_factory):
    d = tmp_path_factory.mktemp("embed")
    shutil.copytree(ROOT / "tests/embed/pricing", d / "pricing")
    (d / "pyproject.toml").write_text('[project]\nname = "pricing"\nversion = "0"\n')
    r = run([sys.executable, "-m", "lean_python.cli", "sync", "--package", "pricing"], d)
    assert r.returncode == 0, r.stderr
    return d


def check(project, code):
    r = run([sys.executable, "-c", code], project)
    assert r.returncode == 0, r.stderr
    return r.stdout


def test_generated_blocks(project):
    assert (project / "pricing/_lean/blocks.json").exists()
    out = check(
        project,
        """
from pricing.api import pricing, geometry, report
from pricing.models import LineItem
items = [LineItem(sku="a", qty=2, unitPrice=100), LineItem(sku="b", qty=1, unitPrice=50)]
print(pricing.subtotal(items))
print(pricing.total(items, pricing.Discount.percent(p=10)))
r = geometry.Range(lo=1, hi=5)
print(report.describe(r))
print(isinstance(r, geometry.Range))
""",
    )
    assert out.split("\n")[:4] == ["250", "225", "[1, 5] width 4", "True"]


def test_user_model_constraints_reach_lean(project):
    out = check(
        project,
        """
from pydantic import ValidationError
from pricing.api import pricing
from pricing.models import LineItem
bad = LineItem.model_construct(sku="x", qty=0, unitPrice=1)
try:
    pricing.subtotal([bad])
except ValidationError as e:
    print("rejected", "1 ≤ qty" in str(e))
""",
    )
    assert out.strip() == "rejected True"


def test_fastapi(project):
    out = check(
        project,
        """
from fastapi.testclient import TestClient
from pricing.api import app
c = TestClient(app)
items = [{"sku": "a", "qty": 2, "unitPrice": 100}]
print(c.post("/total", json={"items": items, "discount": {"percent": {"p": 10}}}).json())
print(c.post("/total", json={"items": items, "discount": "none"}).json())
print(c.post("/total", json={"items": items, "discount": {"percent": {"p": 150}}}).status_code)
print(c.post("/total", json={"items": [{"sku": "a", "qty": 0, "unitPrice": 1}], "discount": "none"}).status_code)
body = c.get("/openapi.json").json()["components"]["schemas"]["Body_post_total_total_post"]
tags = [v.get("const") or next(iter(v["properties"])) for v in body["properties"]["discount"]["oneOf"]]
print(tags == ["none", "percent", "fixed"])
""",
    )
    assert out.split("\n")[:5] == ["180", "200", "422", "422", "True"]


def test_stale_block(project, tmp_path):
    d = tmp_path / "p"
    shutil.copytree(project, d)
    api = d / "pricing/api.py"
    api.write_text(
        api.read_text().replace(
            "def Range.width (r : Range) : Nat := r.hi - r.lo", "def Range.width (r : Range) : Nat := r.hi"
        )
    )
    r = run([sys.executable, "-c", "import pricing.api"], d)
    assert r.returncode != 0
    assert "LeanBlockStale" in r.stderr


def test_lean_error_points_at_python(tmp_path):
    d = tmp_path / "e"
    (d / "bad").mkdir(parents=True)
    (d / "pyproject.toml").write_text('[project]\nname = "bad"\nversion = "0"\n')
    (d / "bad/__init__.py").write_text("")
    (d / "bad/m.py").write_text(
        'from lean_python import lean\n\nm = lean("m", r"""\ndef f (n : Nat) : Nat := n\n\ntheorem wrong : f 1 = 2 := by rfl\n""")\n'
    )
    r = run([sys.executable, "-m", "lean_python.cli", "sync", "--package", "bad"], d)
    assert r.returncode == 254
    assert f"{d / 'bad/m.py'}:6:" in r.stderr, r.stderr
    assert "lean block m" in r.stderr


def test_auto_sync(project, tmp_path):
    d = tmp_path / "a"
    shutil.copytree(project, d)
    api = d / "pricing/api.py"
    api.write_text(api.read_text().replace("width {r.width}", "w={r.width}"))
    env_code = "import os; os.environ['LEAN_PYTHON_AUTO_SYNC']='1'\nfrom pricing.api import report, geometry\nprint(report.describe(geometry.Range(lo=0, hi=2)))"
    out = check(d, env_code)
    assert out.strip().endswith("[0, 2] w=2")


del pathlib


def test_enums_literals_and_unions(project):
    out = check(
        project,
        """
from pricing.orders import orders
from pricing.models import Order, Cat, Dog, Status, LineItem
o = Order(status=Status.open, kind="retail", items=[LineItem(sku="a", qty=1, unitPrice=1)], pet=Cat(name="tama", lives=9))
print(orders.describe(o))
print(orders.describe(Order(status="done", kind="wholesale", items=[], pet=Dog(name="pochi", good=True))))
c = orders.close(o)
print(type(c).__name__, c.status is Status.closed, c.kind == "retail", c.pet, c.model_dump_json())
""",
    )
    assert out.split("\n")[:3] == [
        "open retail 1 items, cat tama with 9 lives",
        "closed wholesale 0 items, dog pochi",
        'Order True True None {"status":"done","kind":"retail","items":[{"sku":"a","qty":1,"unitPrice":1}],"pet":null}',
    ]
