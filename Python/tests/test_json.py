"""The generated models serialize and parse the JSON of Lean's `deriving ToJson, FromJson`."""

import json
import subprocess

import pytest
from conftest import ROOT, generate
from pydantic import TypeAdapter


@pytest.fixture(scope="module")
def js():
    roots = [f"LeanPythonTest.Json.{n}" for n in ("outers", "shapes", "tokens", "colors", "trees", "names")]
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
        (js.Names, js.names()),
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
    assert TypeAdapter(js.Tree).validate_json(json.dumps(oracle_lines[-3])) == js.trees()[-1]


def test_field_names(js):
    n = js.Names(note="n", lambda_=1, x_prime=2)
    assert json.loads(n.model_dump_json()) == {"note": "n", "lambda": 1, "x'": 2}
    assert json.loads(js.Names(lambda_=1, x_prime=2).model_dump_json()) == {"lambda": 1, "x'": 2}
    assert js.Names.model_validate_json('{"lambda": 1, "x\'": 2}') == js.Names(lambda_=1, x_prime=2)
