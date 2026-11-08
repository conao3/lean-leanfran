//! The todo list as Lean definitions, with proofs of their properties. The CLI is `main.rs`.

lean_rust::lean! {
    /// Tasks and the operations on the list.
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

    def initial : Todo := ⟨[], 1⟩

    def addTask (t : Todo) (title : String) : Todo :=
      { tasks := t.tasks ++ [⟨t.nextId, title, false⟩], nextId := t.nextId + 1 }

    def completeTask (t : Todo) (id : Nat) : Todo :=
      { t with tasks := t.tasks.map fun x => if x.id == id then { x with done := true } else x }

    def removeTask (t : Todo) (id : Nat) : Todo :=
      { t with tasks := t.tasks.filter (·.id != id) }

    def hasTask (t : Todo) (id : Nat) : Bool := t.tasks.any (·.id == id)

    def pendingTasks (t : Todo) : List Task := t.tasks.filter (!·.done)

    theorem addTask_adds_one (t : Todo) (s : String) :
        (addTask t s).tasks.length = t.tasks.length + 1 := by
      simp [addTask]

    theorem addTask_advances_id (t : Todo) (s : String) :
        (addTask t s).nextId = t.nextId + 1 := rfl

    theorem completeTask_keeps_length (t : Todo) (id : Nat) :
        (completeTask t id).tasks.length = t.tasks.length := by
      simp [completeTask]

    theorem removeTask_removes (t : Todo) (id : Nat) :
        hasTask (removeTask t id) id = false := by
      simp [hasTask, removeTask, List.any_filter]

    theorem pendingTasks_are_pending (t : Todo) (x : Task) (h : x ∈ pendingTasks t) :
        x.done = false := by
      simp [pendingTasks] at h
      exact h.2
    "#
}
