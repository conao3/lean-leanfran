import json
import tempfile
from pathlib import Path

from pydantic import ValidationError

from todo.model import todos

P = todos.Priority
store = Path(tempfile.mkdtemp()) / "todos.json"

ts = todos.empty()
ts = todos.add(ts, "write the README", P.high)
ts = todos.add(ts, "publish to PyPI", P.normal)
ts = todos.add(ts, "water the plants", P.low)
ts = todos.complete(ts, 0)
store.write_text(ts.model_dump_json())
print(store.read_text())

loaded = todos.Todos.model_validate_json(store.read_text())
print([t.title for t in todos.pending(loaded)])
print([t.title for t in todos.byPriority(loaded, P.high)])

tampered = json.loads(store.read_text())
tampered["items"][1]["id"] = 7
try:
    todos.Todos.model_validate_json(json.dumps(tampered))
except ValidationError as e:
    print("rejected:", e.errors()[0]["msg"])
