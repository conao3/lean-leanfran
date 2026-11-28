import pytest
from conftest import ROOT

from leanfran import cli, embed


@pytest.mark.parametrize(
    "args",
    [[], ["sync", "--package", "p"], ["scan", "--root", "."], ["scan", "--root", ".", "--dir"], ["translate"]],
)
def test_invalid_parameters(args, capsys):
    assert cli.main(args) == 252
    output = capsys.readouterr()
    assert not output.out
    assert "usage: python -m leanfran.cli scan --root <root> --dir <package>" in output.err


def test_versions_come_from_the_compiler(monkeypatch, capsys):
    for var in ("LEANFRAN_VERSION", "LEANFRAN_GENERATOR_VERSION", "LEANFRAN_LEAN_VERSION"):
        monkeypatch.delenv(var, raising=False)
    assert cli.main(["scan", "--root", ".", "--dir", "."]) == 255
    assert "run leanfran --lang python sync, check or status" in capsys.readouterr().err


def test_lean_version_matches_the_toolchain():
    toolchain = (ROOT.parent.parent / "lean-toolchain").read_text().strip()
    assert toolchain == f"leanprover/lean4:v{embed.LEAN_VERSION}"
