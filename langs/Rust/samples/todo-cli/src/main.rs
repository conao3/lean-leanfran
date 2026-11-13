//! A command-line todo list. The list and its operations are Lean definitions in `lib.rs`;
//! this file parses the arguments, stores the list in a JSON file and prints the results.

use serde_json::{json, Value};
use std::process::ExitCode;
use todo_cli::model::{self as todo, Task, Todo};

struct Opts {
    data_file: String,
    text: bool,
    args: Vec<String>,
}

fn parse(args: Vec<String>) -> Result<Opts, String> {
    let mut opts = Opts {
        data_file: "todo.json".into(),
        text: false,
        args: Vec::new(),
    };
    let mut it = args.into_iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--data-file" => opts.data_file = it.next().ok_or("--data-file needs a path")?,
            "--output" => match it.next().as_deref() {
                Some("json") => opts.text = false,
                Some("text") => opts.text = true,
                _ => return Err("--output must be json or text".into()),
            },
            _ => opts.args.push(a),
        }
    }
    Ok(opts)
}

fn load(path: &str) -> Result<Todo, String> {
    let Ok(text) = std::fs::read_to_string(path) else {
        return Ok(todo::initial());
    };
    let v: Value = serde_json::from_str(&text).map_err(|e| format!("{path}: {e}"))?;
    let tasks = v["tasks"]
        .as_array()
        .ok_or(format!("{path}: no tasks"))?
        .iter()
        .map(|t| Task {
            id: t["id"].as_u64().unwrap_or(0).into(),
            title: t["title"].as_str().unwrap_or("").into(),
            done: t["done"].as_bool().unwrap_or(false),
        })
        .collect();
    let next_id = v["next_id"].as_u64().ok_or(format!("{path}: no next_id"))?;
    Ok(Todo {
        tasks,
        next_id: next_id.into(),
    })
}

fn num(n: &leanfran::Nat) -> u64 {
    u64::try_from(n).expect("task ids fit in u64")
}

fn save(path: &str, t: &Todo) -> Result<(), String> {
    let tasks: Vec<Value> = t
        .tasks
        .iter()
        .map(|x| json!({"id": num(&x.id), "title": x.title, "done": x.done}))
        .collect();
    let v = json!({"tasks": tasks, "next_id": num(&t.next_id)});
    std::fs::write(path, v.to_string()).map_err(|e| format!("{path}: {e}"))
}

fn task_json(x: &Task) -> Value {
    json!({"TaskId": num(&x.id), "Title": x.title, "Done": x.done})
}

fn print_tasks(tasks: &[Task], text: bool) {
    if text {
        for x in tasks {
            let mark = if x.done { "x" } else { " " };
            println!("{}\t[{mark}]\t{}", num(&x.id), x.title);
        }
    } else {
        let v: Vec<Value> = tasks.iter().map(task_json).collect();
        println!("{}", json!({ "Tasks": v }));
    }
}

fn task_id(args: &[&str]) -> Result<u64, String> {
    match args {
        ["--task-id", n] => n.parse().map_err(|_| format!("not a task id: {n}")),
        _ => Err("--task-id <n> is required".into()),
    }
}

fn run(opts: &Opts) -> Result<(), (u8, String)> {
    let bad = |e: String| (252, e);
    let args: Vec<&str> = opts.args.iter().map(String::as_str).collect();
    let t = load(&opts.data_file).map_err(bad)?;
    match args.as_slice() {
        ["task", "create-task", "--title", title] => {
            let t = todo::add_task(t, title);
            let x = t.tasks.last().expect("add_task adds a task").clone();
            save(&opts.data_file, &t).map_err(bad)?;
            println!("{}", json!({ "Task": task_json(&x) }));
        }
        ["task", "list-tasks", rest @ ..] => {
            let all = match rest {
                [] | ["--status", "pending"] => false,
                ["--status", "all"] => true,
                _ => return Err(bad("--status must be pending or all".into())),
            };
            let tasks = if all { t.tasks } else { todo::pending_tasks(t) };
            print_tasks(&tasks, opts.text);
        }
        ["task", "complete-task", rest @ ..] => {
            let id = task_id(rest).map_err(bad)?;
            if !todo::has_task(t.clone(), id.into()) {
                return Err((254, format!("no task {id}")));
            }
            let t = todo::complete_task(t, id.into());
            save(&opts.data_file, &t).map_err(bad)?;
            let x = t.tasks.iter().find(|x| num(&x.id) == id).expect("the task exists");
            println!("{}", json!({ "Task": task_json(x) }));
        }
        ["task", "delete-task", rest @ ..] => {
            let id = task_id(rest).map_err(bad)?;
            if !todo::has_task(t.clone(), id.into()) {
                return Err((254, format!("no task {id}")));
            }
            let t = todo::remove_task(t, id.into());
            save(&opts.data_file, &t).map_err(bad)?;
            println!("{}", json!({ "TaskId": id }));
        }
        _ => return Err(bad(
            "usage: todo [--data-file <path>] [--output json|text] task create-task|list-tasks|complete-task|delete-task".into(),
        )),
    }
    Ok(())
}

fn main() -> ExitCode {
    let opts = match parse(std::env::args().skip(1).collect()) {
        Ok(o) => o,
        Err(e) => {
            eprintln!("todo: {e}");
            return ExitCode::from(252);
        }
    };
    match run(&opts) {
        Ok(()) => ExitCode::SUCCESS,
        Err((code, msg)) => {
            eprintln!("todo: {msg}");
            ExitCode::from(code)
        }
    }
}
