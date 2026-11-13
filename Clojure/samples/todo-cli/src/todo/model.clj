(ns todo.model
  "The todo list as Lean definitions, with proofs of their properties."
  (:require
    [leanfran.core :refer [deflean]]))


(deflean model
  (structure Task [id Nat title String done Bool])

  (structure Todo [tasks (List Task) next-id Nat])

  (def initial
    [] Todo
    {:tasks [] :next-id 1})

  (def add-task
    [t Todo title String] Todo
    {:tasks (++ (.tasks t) [(the Task {:id (.next-id t) :title title :done false})])
     :next-id (+ (.next-id t) 1)})

  (def complete-task
    [t Todo id Nat] Todo
    (with t {:tasks (.map (.tasks t)
                          (fn [x] (if (== (.id x) id) (with x {:done true}) x)))}))

  (def remove-task
    [t Todo id Nat] Todo
    (with t {:tasks (.filter (.tasks t) (fn [x] (!= (.id x) id)))}))

  (def has-task
    [t Todo id Nat] Bool
    (.any (.tasks t) (fn [x] (== (.id x) id))))

  (def pending-tasks
    [t Todo] (List Task)
    (.filter (.tasks t) (fn [x] (! (.done x)))))

  (theorem add-task-adds-one [t Todo s String]
           (= (.length (.tasks (add-task t s))) (+ (.length (.tasks t)) 1))
           (by (simp [add-task])))

  (theorem add-task-advances-id [t Todo s String]
           (= (.next-id (add-task t s)) (+ (.next-id t) 1))
           rfl)

  (theorem complete-task-keeps-length [t Todo id Nat]
           (= (.length (.tasks (complete-task t id))) (.length (.tasks t)))
           (by (simp [complete-task])))

  (theorem remove-task-removes [t Todo id Nat]
           (= (has-task (remove-task t id) id) false)
           (by (simp [has-task remove-task List.any_filter])))

  (theorem pending-tasks-are-pending [t Todo x Task h (in x (pending-tasks t))]
           (= (.done x) false)
           (by (simp [pending-tasks] at h) (exact (.2 h)))))
