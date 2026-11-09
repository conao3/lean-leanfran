"""The generated models serialize and parse the JSON of Lean's `deriving ToJson, FromJson`."""

import json
import subprocess

import pytest
from conftest import ROOT, generate
from pydantic import TypeAdapter


@pytest.fixture(scope="module")
def js():
    roots = [f"LeanPythonTest.Json.{n}" for n in ("outers", "shapes", "tokens", "colors", "trees")]
    return generate("LeanPythonTest.Json", ROOT / "test-out/json_types.py", roots)


@pytest.fixture(scope="module")
def oracle_lines():
    out = subprocess.run([str(ROOT / ".lake/build/bin/oracle-json")], check=True, capture_output=True, text=True)
    return [json.loads(line) for line in out.stdout.splitlines()]


def test_same_json(js, oracle_lines):
    groups = [
        (js.Outer, js.outers()),
        (js.Shape, js.shapes()),
        (js.Token, js.tokens()),
        (js.Color, js.colors()),
        (js.Tree, js.trees()),
    ]
    ours = []
    for t, values in groups:
        ta = TypeAdapter(t)
        for v in values:
            ours.append(json.loads(ta.dump_json(v)))
            assert ta.validate_json(ta.dump_json(v)) == v
    assert ours == oracle_lines


def test_parse_lean_json(js, oracle_lines):
    ta = TypeAdapter(js.Outer)
    assert ta.validate_json(json.dumps(oracle_lines[0])) == js.outers()[0]
    assert TypeAdapter(js.Tree).validate_json(json.dumps(oracle_lines[-1])) == js.trees()[-1]
