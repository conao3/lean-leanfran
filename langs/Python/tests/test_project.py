"""`leanfran --lang python sync|status` on projects: exit codes, packages that share a root, old layouts."""

import json
import os
import shutil
import subprocess
import sys

import pytest
from conftest import CLI, ROOT

BLOCK = 'from leanfran import lean\n\n{name} = lean("{name}", r"""\ndef {fn} (n : Nat) : Nat := n + {k}\n""")\n'


def run(args, cwd, env=None):
    env = {**os.environ, "LEANFRAN_CLI": str(CLI), **(env or {})}
    return subprocess.run(
        [str(CLI), "--lang", "python", *args], cwd=cwd, env=env, capture_output=True, text=True, check=False
    )


def package(root, pkg, name="m", fn="f", k=1):
    (root / pkg).mkdir(parents=True, exist_ok=True)
    (root / pkg / "__init__.py").write_text("")
    (root / pkg / "m.py").write_text(BLOCK.format(name=name, fn=fn, k=k))


@pytest.fixture
def two(tmp_path):
    (tmp_path / "pyproject.toml").write_text('[project]\nname = "two"\nversion = "0"\n')
    package(tmp_path, "a", fn="fa")
    package(tmp_path, "b", fn="fb")
    for pkg in ("a", "b"):
        r = run(["sync", "--package", pkg], tmp_path)
        assert r.returncode == 0, r.stderr
    return tmp_path


def manifest(root):
    return json.loads((root / "leanfran.manifest.json").read_text())["languages"]["python"]


def test_packages_share_the_manifest(two):
    m = manifest(two)
    assert [b["name"] for b in m["blocks"]] == ["a.m:m", "b.m:m"]
    assert m["files"] == ["a/_lean/__init__.py", "a/_lean/blocks.json", "b/_lean/__init__.py", "b/_lean/blocks.json"]
    assert (two / "a/_lean/a__m__m.py").exists()
    for pkg in ("a", "b"):
        r = run(["status", "--package", pkg], two)
        assert (r.returncode, r.stdout) == (0, ""), r.stderr
    package(two, "a", fn="fa", k=2)
    r = run(["status", "--package", "a"], two)
    assert (r.returncode, r.stdout) == (1, "a.m:m: stale\n")
    r = run(["sync", "--package", "a"], two)
    assert r.returncode == 0, r.stderr
    assert manifest(two)["files"] == m["files"]
    assert [b["name"] for b in manifest(two)["blocks"]] == ["a.m:m", "b.m:m"]
    assert (two / "b/_lean/b__m__m.py").exists()
    r = run(["status", "--package", "b"], two)
    assert (r.returncode, r.stdout) == (0, ""), r.stderr


def test_removed_block(two):
    (two / "a/m.py").write_text("")
    r = run(["status", "--package", "a"], two)
    assert (r.returncode, r.stdout) == (1, "a.m:m: removed\n")
    r = run(["sync", "--package", "a"], two)
    assert r.returncode == 0, r.stderr
    assert not (two / "a/_lean/a__m__m.py").exists()
    assert (two / "b/_lean/b__m__m.py").exists()
    assert [b["name"] for b in manifest(two)["blocks"]] == ["b.m:m"]


def test_old_layout(tmp_path):
    d = tmp_path / "p"
    shutil.copytree(ROOT / "tests/embed", d)
    (d / "leanfran.manifest.json").unlink()
    api = d / "pricing/api.py"
    api.write_text(api.read_text().replace("width {r.width}", "w={r.width}"))
    r = run(["sync", "--package", "pricing"], d)
    assert r.returncode == 0, r.stderr
    r = run(["status", "--package", "pricing"], d)
    assert (r.returncode, r.stdout) == (0, ""), r.stderr


def test_bad_parameters(tmp_path):
    for args in (["sync"], ["sync", "--package", "a", "--bogus"], ["status", "--package", "a", "--verbose"]):
        r = run(args, tmp_path)
        assert r.returncode == 252, (args, r.stderr)
    r = run(["check", "--package", "a", "--require", "maybe"], tmp_path)
    assert r.returncode == 252
    assert "expected '--require proved'" in r.stderr


def test_import_failure(tmp_path):
    (tmp_path / "pyproject.toml").write_text('[project]\nname = "p"\nversion = "0"\n')
    package(tmp_path, "p")
    (tmp_path / "p/broken.py").write_text("import os\n\nraise RuntimeError('boom')\n")
    for command in ("sync", "status"):
        r = run([command, "--package", "p"], tmp_path)
        assert r.returncode == 254, r.stderr
        assert "p/broken.py:3: RuntimeError: boom" in r.stderr
    assert not (tmp_path / "leanfran.manifest.json").exists()


def python_wrapper(tmp_path, body):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    wrapper = bin_dir / "python3"
    wrapper.write_text(f"#!/bin/sh\n{body}\n")
    wrapper.chmod(0o755)
    return {"PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}


def test_package_not_installed(tmp_path):
    package(tmp_path, "p")
    env = python_wrapper(tmp_path, "exit 1")
    r = run(["status", "--package", "p"], tmp_path, env)
    assert r.returncode == 255
    assert "cannot import the Python package `leanfran`" in r.stderr


@pytest.mark.parametrize(
    ("var", "name"),
    [
        ("LEANFRAN_VERSION", "release version"),
        ("LEANFRAN_GENERATOR_VERSION", "generator version"),
        ("LEANFRAN_LEAN_VERSION", "Lean version"),
    ],
)
def test_version_mismatch(tmp_path, var, name):
    package(tmp_path, "p")
    env = python_wrapper(tmp_path, f'{var}=0.0.0 exec {sys.executable} "$@"')
    for command in ("sync", "status"):
        r = run([command, "--package", "p"], tmp_path, env)
        assert r.returncode == 255, r.stderr
        assert f'compiler {name} "0.0.0"' in r.stderr
