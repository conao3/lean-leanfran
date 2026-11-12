#!/usr/bin/env bash
# Run a session of the todo CLI and compare its output with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
data=$(mktemp -d)/todo.edn
{
  ./todo --data-file "$data" task create-task --title "Buy milk"
  ./todo --data-file "$data" task create-task --title "Write the report"
  ./todo --data-file "$data" task complete-task --task-id 1
  ./todo --data-file "$data" task list-tasks
  ./todo --data-file "$data" --output text task list-tasks --status all
  ./todo --data-file "$data" task delete-task --task-id 1
  ./todo --data-file "$data" --output text task list-tasks --status all
  ./todo --data-file "$data" task complete-task --task-id 9 2>&1 || echo "exit $?"
} > "$data.out"
diff -u expected.txt "$data.out"
echo "todo-cli: session matches expected.txt"
