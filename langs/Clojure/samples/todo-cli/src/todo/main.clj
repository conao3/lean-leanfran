(ns todo.main
  "Command-line interface of the todo list. The list operations are the Lean
  definitions in `todo.model`; this namespace reads arguments, stores the
  list in an EDN file, and prints results."
  (:gen-class)
  (:require
    [clojure.data.json :as json]
    [clojure.edn :as edn]
    [clojure.java.io :as io]
    [clojure.string :as str]
    [todo.model :as model]))


(def usage
  "usage: todo [--data-file <path>] [--output json|text] <command> <subcommand> [parameters]

  todo task create-task --title <text>
  todo task list-tasks [--status pending|all]
  todo task complete-task --task-id <n>
  todo task delete-task --task-id <n>

--data-file defaults to todo.edn in the working directory.
")


(defn- fail
  [code msg]
  (throw (ex-info msg {:exit code})))


(defn- parse-params
  [args]
  (loop [args args acc {}]
    (cond
      (empty? args) acc
      (and (str/starts-with? (first args) "--") (second args))
      (recur (nnext args) (assoc acc (keyword (subs (first args) 2)) (second args)))
      :else (fail 252 (str "invalid parameter: " (first args))))))


(defn- parse-global
  [args]
  (loop [args args acc {:data-file "todo.edn" :output "json"}]
    (case (first args)
      "--data-file" (recur (nnext args) (assoc acc :data-file (second args)))
      "--output" (recur (nnext args) (assoc acc :output (second args)))
      [acc args])))


(defn- task-id
  [params]
  (or (some-> (:task-id params) parse-long)
      (fail 252 "--task-id <n> is required")))


(defn- load-todo
  [file]
  (if (.exists (io/file file))
    (edn/read-string (slurp file))
    (model/initial)))


(defn- save-todo!
  [file todo]
  (spit file (pr-str todo)))


(defn- ->output
  [task]
  {"TaskId" (:id task) "Title" (:title task) "Done" (:done task)})


(defn- run
  [todo [command subcommand & args]]
  (let [params (parse-params args)]
    (when-not (= "task" command)
      (fail 252 (str "unknown command: " command)))
    (case subcommand
      "create-task"
      (let [title (or (:title params) (fail 252 "--title <text> is required"))
            todo' (model/add-task todo title)]
        [todo' {"Task" (->output (last (:tasks todo')))}])

      "list-tasks"
      (let [tasks (case (:status params "pending")
                    "pending" (model/pending-tasks todo)
                    "all" (:tasks todo)
                    (fail 252 "--status must be pending or all"))]
        [todo {"Tasks" (mapv ->output tasks)}])

      "complete-task"
      (let [id (task-id params)]
        (when-not (model/has-task todo id) (fail 254 (str "no task " id)))
        (let [todo' (model/complete-task todo id)]
          [todo' {"Task" (->output (first (filter #(= id (:id %)) (:tasks todo'))))}]))

      "delete-task"
      (let [id (task-id params)]
        (when-not (model/has-task todo id) (fail 254 (str "no task " id)))
        [(model/remove-task todo id) {"TaskId" id}])

      (fail 252 (str "unknown subcommand: " subcommand)))))


(defn- print-text
  [result]
  (doseq [t (or (get result "Tasks") (some-> (get result "Task") vector))]
    (println (str (get t "TaskId") "\t" (if (get t "Done") "[x]" "[ ]") "\t" (get t "Title"))))
  (when-let [id (get result "TaskId")]
    (when-not (get result "Task") (println "deleted" id))))


(defn -main
  [& args]
  (let [code (try
               (let [[{:keys [data-file output]} args] (parse-global args)]
                 (if (or (empty? args) (= ["help"] args))
                   (do (print usage) 0)
                   (let [[todo' result] (run (load-todo data-file) args)]
                     (save-todo! data-file todo')
                     (case output
                       "json" (println (json/write-str result))
                       "text" (print-text result)
                       (fail 252 "--output must be json or text"))
                     0)))
               (catch clojure.lang.ExceptionInfo e
                 (binding [*out* *err*] (println "todo:" (ex-message e)))
                 (:exit (ex-data e) 255)))]
    (flush)
    (System/exit code)))
