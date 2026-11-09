
namespace LeanPythonEmbed.todo.model.todos


inductive Priority where
  | low | normal | high
  deriving DecidableEq

structure Todo where
  id : Nat
  title : String
  done : Bool
  priority : Priority

/-- The todo list. Every id is below `nextId`, so `add` never reuses an id. -/
structure Todos where
  items : List Todo
  nextId : Nat
  fresh : ∀ t ∈ items, t.id < nextId

def empty : Todos := ⟨[], 0, by simp⟩

def add (ts : Todos) (title : String) (priority : Priority) : Todos where
  items := ts.items ++ [{ id := ts.nextId, title, done := false, priority }]
  nextId := ts.nextId + 1
  fresh := by
    intro t ht
    simp only [List.mem_append, List.mem_singleton] at ht
    rcases ht with h | h
    · have := ts.fresh t h; omega
    · subst h; simp

def complete (ts : Todos) (id : Nat) : Todos where
  items := ts.items.map fun t => if t.id = id then { t with done := true } else t
  nextId := ts.nextId
  fresh := by
    intro t ht
    simp only [List.mem_map] at ht
    obtain ⟨u, hu, rfl⟩ := ht
    have := ts.fresh u hu
    split <;> simpa

def pending (ts : Todos) : List Todo := ts.items.filter (!·.done)

def byPriority (ts : Todos) (p : Priority) : List Todo := ts.items.filter (·.priority = p)

theorem add_length (ts : Todos) (title : String) (p : Priority) :
    (add ts title p).items.length = ts.items.length + 1 := by
  simp [add]

theorem complete_length (ts : Todos) (id : Nat) : (complete ts id).items.length = ts.items.length := by
  simp [complete]


end LeanPythonEmbed.todo.model.todos
