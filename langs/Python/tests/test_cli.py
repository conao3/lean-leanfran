import pytest

from leanfran.cli import main


@pytest.mark.parametrize("command", ["sync", "check", "status"])
def test_command_help(command, capsys):
    assert main([command, "--help"]) == 0
    output = capsys.readouterr()
    assert f"usage: leanfran --lang python {command}" in output.out
    assert "--package" in output.out
    assert not output.err


@pytest.mark.parametrize(
    ("args", "message"),
    [
        (["sync"], "the following arguments are required: --package"),
        (["status", "--package", "example", "--bogus"], "unrecognized arguments: --bogus"),
        (["check", "--package", "example", "--require", "maybe"], "invalid choice: 'maybe'"),
    ],
)
def test_invalid_parameters(args, message, capsys):
    assert main(args) == 252
    output = capsys.readouterr()
    assert not output.out
    assert message in output.err
    assert "leanfran: 2\n" not in output.err
