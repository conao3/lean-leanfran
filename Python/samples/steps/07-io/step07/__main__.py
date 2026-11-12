import tempfile
from pathlib import Path

from step07.code import m

f = Path(tempfile.mkdtemp()) / "log.txt"
f.write_text("one\ntwo\n")
m.appendLine(str(f), "three")
print(m.countLines(str(f)))
print(m.runEcho("from a child process"))
try:
    m.countLines(str(f.parent / "missing.txt"))
except OSError as e:
    print(type(e).__name__, "no such file" in str(e))
