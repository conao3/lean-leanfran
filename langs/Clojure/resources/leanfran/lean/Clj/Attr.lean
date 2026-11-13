import Lean

/-- The lemmas that turn the models of `clojure.core` back into Lean's own
    operations: `simp only [clj_simp]`. -/
register_simp_attr clj_simp
