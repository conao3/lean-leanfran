import importlib.util
import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLI = ROOT / ".lake/build/bin/lean-python"


def generate(module, out, roots=()):
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(CLI),
            "module",
            "generate",
            "--module-name",
            module,
            "--search-path",
            str(ROOT / ".lake/build/lib/lean"),
            "--output-file",
            str(out),
            "--output",
            "text",
            *(["--roots", *roots] if roots else []),
        ],
        check=True,
        capture_output=True,
    )
    spec = importlib.util.spec_from_file_location(out.stem, out)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def pub():
    return generate("LeanPythonTest.Public", ROOT / "test-out/public.py")
