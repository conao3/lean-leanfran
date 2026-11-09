"""`@model`, `lean-py check` and `lean-py status`, and property tests against the Lean specs."""

import json
import os
import shutil
import subprocess
import sys

import pytest
from conftest import CLI, ROOT


def run(args, cwd):
    env = {**os.environ, "LEAN_PYTHON_CLI": str(CLI), "PYTHONPATH": str(cwd)}
    return subprocess.run([sys.executable, *args], cwd=cwd, env=env, capture_output=True, text=True, check=False)


@pytest.fixture(scope="module")
def project(tmp_path_factory):
    d = tmp_path_factory.mktemp("verify")
    for name in ("calc", "lean", "pyproject.toml"):
        src = ROOT / "tests/verify" / name
        if src.is_dir():
            shutil.copytree(src, d / name, ignore=shutil.ignore_patterns("_lean", "__pycache__"))
        else:
            shutil.copy(src, d / name)
    r = run(["-m", "lean_python.cli", "check", "--package", "calc"], d)
    assert r.returncode == 0, r.stderr
    return d


def statuses(stdout):
    return {(q, label): st for st, q, label in (line.split() for line in stdout.splitlines() if line.strip())}


EXPECTED = {
    ("calc.calc:clamp", "refines"): "proved",
    ("calc.calc:clamp", "in_range"): "proved",
    ("calc.calc:first_or", "refines"): "proved",
    ("calc.calc:sum_to", "refines"): "sorry",
    ("calc.calc:sum_to", "returns_nat"): "missing",
    ("calc.calc:sum_abs", "nonneg"): "missing",
}


def test_check(project):
    lock = json.loads((project / "lean-python.lock").read_text())
    got = {(q, label): st for q, e in lock.items() for label, st in e["obligations"].items()}
    assert got == EXPECTED
    r = run(["-m", "lean_python.cli", "check", "--package", "calc", "--require", "proved"], project)
    assert r.returncode == 254


def test_status_marks_changed_functions(project, tmp_path):
    d = tmp_path / "p"
    shutil.copytree(project, d, ignore=shutil.ignore_patterns(".lean-python"))
    r = run(["-m", "lean_python.cli", "status", "--package", "calc"], d)
    assert statuses(r.stdout) == EXPECTED
    calc = d / "calc/calc.py"
    calc.write_text(calc.read_text().replace("    if x > hi:\n        return hi\n", ""))
    r = run(["-m", "lean_python.cli", "status", "--package", "calc"], d)
    got = statuses(r.stdout)
    assert got[("calc.calc:clamp", "refines")] == "stale"
    assert got[("calc.calc:first_or", "refines")] == "proved"


def test_wrong_proof_and_wrong_statement(project, tmp_path):
    d = tmp_path / "w"
    shutil.copytree(project, d)
    proofs = d / "lean/Proofs/Calc.lean"
    text = proofs.read_text()
    text = text.replace(
        "theorem first_or.proof.refines : first_or.obligation.refines := by",
        "theorem first_or.proof.refines : True := by\n  trivial\n\ntheorem unused : first_or.obligation.refines := by",
    )
    proofs.write_text(text)
    (d / "lean/Proofs/Broken.lean").write_text(
        "import LeanPythonModel.calc.calc\n\ntheorem LeanPythonModel.«calc».«calc».sum_abs.proof.nonneg :\n"
        "    LeanPythonModel.«calc».«calc».sum_abs.obligation.nonneg := by\n  intro xs r h\n  rfl\n"
    )
    r = run(["-m", "lean_python.cli", "check", "--package", "calc"], d)
    got = statuses(r.stdout)
    assert got[("calc.calc:first_or", "refines")] == "mismatch"
    assert got[("calc.calc:sum_abs", "nonneg")] == "failed"
    assert got[("calc.calc:clamp", "refines")] == "proved"


def test_property_checks(project):
    code = """
from lean_python.verify import check_model, model, PropertyFailure
from calc import calc
from calc.spec import spec
check_model(calc.clamp)
check_model(calc.first_or)
check_model(calc.sum_to, max_examples=50)

@model(refines=spec.clampSpec, requires=spec.ordered)
def bad_clamp(x: int, lo: int, hi: int) -> int:
    return max(lo, x)

try:
    check_model(bad_clamp)
except PropertyFailure as e:
    print("counterexample", "the spec gives" in str(e))
"""
    r = run(["-c", code], project)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "counterexample True"
