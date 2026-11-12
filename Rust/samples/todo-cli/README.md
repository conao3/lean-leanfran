# todo-cli

A command-line todo list. The list and its operations are Lean definitions written with
`lean!` in [`src/lib.rs`](src/lib.rs), together with proofs of their properties;
[`src/main.rs`](src/main.rs) is plain Rust that parses arguments, stores the list in a JSON
file and prints the results.

## The model

```rust
lean_rust::lean! {
    pub mod model;
    r#"
    structure Task where
      id : Nat
      title : String
      done : Bool
      deriving DecidableEq

    structure Todo where
      tasks : List Task
      nextId : Nat
      deriving DecidableEq

    def addTask (t : Todo) (title : String) : Todo :=
      { tasks := t.tasks ++ [⟨t.nextId, title, false⟩], nextId := t.nextId + 1 }

    theorem removeTask_removes (t : Todo) (id : Nat) :
        hasTask (removeTask t id) id = false := by
      simp [hasTask, removeTask, List.any_filter]
    ...
    "#
}
```

The build script checks these proofs with `lake build`:

| Theorem | Statement |
|---|---|
| `addTask_adds_one` | `addTask` makes the list one task longer |
| `addTask_advances_id` | `addTask` increments `nextId` |
| `completeTask_keeps_length` | `completeTask` keeps the number of tasks |
| `removeTask_removes` | after `removeTask t id`, `hasTask` is false for `id` |
| `pendingTasks_are_pending` | every task in `pendingTasks` is not done |

From Rust, the structures are generated structs with snake_case fields and the definitions
are functions on them:

```rust
use todo_cli::model::{self, Task, Todo};

let t: Todo = model::complete_task(model::add_task(model::initial(), "Buy milk"), 1u64.into());
assert_eq!(t.tasks, vec![Task { id: 1u64.into(), title: "Buy milk".into(), done: true }]);
```

## Usage

```
$ make run ARGS='task create-task --title "Buy milk"'
{"Task":{"TaskId":1,"Title":"Buy milk","Done":false}}
$ ../../target/debug/todo task create-task --title "Write the report"
{"Task":{"TaskId":2,"Title":"Write the report","Done":false}}
$ ../../target/debug/todo task complete-task --task-id 1
{"Task":{"TaskId":1,"Title":"Buy milk","Done":true}}
$ ../../target/debug/todo task list-tasks
{"Tasks":[{"TaskId":2,"Title":"Write the report","Done":false}]}
$ ../../target/debug/todo --output text task list-tasks --status all
1	[x]	Buy milk
2	[ ]	Write the report
$ ../../target/debug/todo task delete-task --task-id 1
{"TaskId":1}
$ ../../target/debug/todo task complete-task --task-id 9
todo: no task 9
```

| Command | Effect |
|---|---|
| `task create-task --title <text>` | add a task |
| `task list-tasks [--status pending\|all]` | list pending (default) or all tasks |
| `task complete-task --task-id <n>` | mark a task done |
| `task delete-task --task-id <n>` | remove a task |

Global options: `--data-file <path>` (default `todo.json` in the working directory) and
`--output json|text`. Exit codes: 0 success, 252 invalid parameters, 254 no such task.

Changing the Lean source makes the next build run Lean: `lake` and the `lean-rust` CLI must be
available (`make` sets `LEAN_RUST_CLI` to the CLI of the repository). The build writes the new
module to `.lean-rust/cache/` and the Lean file to `lean/LeanRustGen/`; commit both.

`make test` runs a session and compares its output with `expected.txt`.
