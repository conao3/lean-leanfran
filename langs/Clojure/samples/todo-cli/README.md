# todo-cli

A command-line todo list. The list and its operations are Lean definitions
written with `deflean` in [`src/todo/model.clj`](src/todo/model.clj), together
with proofs of their properties; [`src/todo/main.clj`](src/todo/main.clj) is
plain Clojure that parses arguments, stores the list in an EDN file, and
prints the results.

## The model

```clojure
(deflean model
  (structure Task [id Nat title String done Bool])

  (structure Todo [tasks (List Task) next-id Nat])

  (def add-task [t Todo title String] Todo
    {:tasks (++ (.tasks t) [(the Task {:id (.next-id t) :title title :done false})])
     :next-id (+ (.next-id t) 1)})

  (def remove-task [t Todo id Nat] Todo
    (with t {:tasks (.filter (.tasks t) (fn [x] (!= (.id x) id)))}))

  (def has-task [t Todo id Nat] Bool
    (.any (.tasks t) (fn [x] (== (.id x) id))))

  (theorem remove-task-removes [t Todo id Nat]
    (= (has-task (remove-task t id) id) false)
    (by (simp [has-task remove-task List.any_filter])))
  ...)
```

Lean checks these proofs when `todo.model` is compiled:

| Theorem | Statement |
|---|---|
| `add-task-adds-one` | `add-task` makes the list one task longer |
| `add-task-advances-id` | `add-task` increments `next-id` |
| `complete-task-keeps-length` | `complete-task` keeps the number of tasks |
| `remove-task-removes` | after `remove-task t id`, `has-task` is false for `id` |
| `pending-tasks-are-pending` | every task in `pending-tasks` is not done |

From Clojure the definitions are ordinary functions on Clojure data: a `Todo`
is a map `{:tasks (...) :next-id n}` and a `Task` is `{:id n :title "..." :done
false}`, so the CLI stores the value returned by Lean directly as EDN.

```clojure
(-> (model/initial) (model/add-task "Buy milk") (model/complete-task 1))
;=> {:tasks ({:id 1, :title "Buy milk", :done true}), :next-id 2}
```

## Usage

The first run expands `deflean`, so it needs `lean`, `lake`, and the `leanfran`
CLI on `PATH`; `make` builds the CLI in the repository root and puts it on
`PATH`. Run everything inside `nix develop` of the repository root.

```
$ make run ARGS='task create-task --title "Buy milk"'
{"Task":{"TaskId":1,"Title":"Buy milk","Done":false}}
$ ./todo task create-task --title "Write the report"
{"Task":{"TaskId":2,"Title":"Write the report","Done":false}}
$ ./todo task complete-task --task-id 1
{"Task":{"TaskId":1,"Title":"Buy milk","Done":true}}
$ ./todo task list-tasks
{"Tasks":[{"TaskId":2,"Title":"Write the report","Done":false}]}
$ ./todo --output text task list-tasks --status all
1	[x]	Buy milk
2	[ ]	Write the report
$ ./todo task delete-task --task-id 1
{"TaskId":1}
$ ./todo task complete-task --task-id 9
todo: no task 9
```

| Command | Effect |
|---|---|
| `task create-task --title <text>` | add a task |
| `task list-tasks [--status pending\|all]` | list pending (default) or all tasks |
| `task complete-task --task-id <n>` | mark a task done |
| `task delete-task --task-id <n>` | remove a task |

Global options: `--data-file <path>` (default `todo.edn` in the working
directory) and `--output json|text`. Exit codes: 0 success, 252 invalid
parameters, 254 no such task.

`make test` runs a session and compares its output with `expected.txt`.
