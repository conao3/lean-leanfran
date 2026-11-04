(ns lean-clj.dsl-test
  (:require
    [clojure.test :as t]
    [lean-clj.dsl :as dsl]))


(t/deftest identifiers
  (t/is (= "isPrime?" (dsl/ident 'is-prime?)))
  (t/is (= "xs.foldLeft" (dsl/ident 'xs.fold-left)))
  (t/is (= "Nat.add_comm" (dsl/ident 'Nat.add_comm)))
  (t/is (= "fieldName" (dsl/ident :field-name))))


(t/deftest terms
  (t/is (= "((a + b) * 2)" (dsl/term '(* (+ a b) 2))))
  (t/is (= "(-x)" (dsl/term '(- x))))
  (t/is (= "(if (n = 0) then 1 else n)" (dsl/term '(if (= n 0) 1 n))))
  (t/is (= "(let x := 1; let y := 2; (x + y))" (dsl/term '(let [x 1 y 2] (+ x y)))))
  (t/is (= "(fun x y => (x * y))" (dsl/term '(fn [x y] (* x y)))))
  (t/is (= "(match n with | 0 => 1 | (k + 1) => k)" (dsl/term '(match n 0 1 (+ k 1) k))))
  (t/is (= "(match a, b with | 0, _ => 1 | _, _ => 2)" (dsl/term '(match [a b] [0 _] 1 [_ _] 2))))
  (t/is (= "(xs.foldl f 0)" (dsl/term '(.foldl xs f 0))))
  (t/is (= "p.x" (dsl/term '(.x p))))
  (t/is (= "{ x := 1, y := 2 }" (dsl/term '{:x 1 :y 2})))
  (t/is (= "{ p with x := 1 }" (dsl/term '(with p {:x 1}))))
  (t/is (= "⟨a, b⟩" (dsl/term '(<> a b))))
  (t/is (= "[1, 2]" (dsl/term [1 2])))
  (t/is (= "#[1, 2]" (dsl/term '(array 1 2))))
  (t/is (= "(Nat → Nat → Bool)" (dsl/term '(-> Nat Nat Bool))))
  (t/is (= "(∀ (n : Nat), (n ≥ 0))" (dsl/term '(forall [n Nat] (>= n 0)))))
  (t/is (= "(3 : Int)" (dsl/term '(the Int 3))))
  (t/is (= "(x ∈ xs)" (dsl/term '(in x xs))))
  (t/is (= "\"a\\\"b\\n\"" (dsl/term "a\"b\n")))
  (t/is (= "'x'" (dsl/term \x)))
  (t/is (= "xs.length" (dsl/term '(lean "xs.length")))))


(t/deftest tactics
  (t/is (= "(by simp [foo, bar]; omega)" (dsl/term '(by (simp [foo bar]) omega))))
  (t/is (= "(by all_goals omega)" (dsl/term '(by (all-goals omega)))))
  (t/is (= "(by cases h <;> simp)" (dsl/term '(by (on-all (cases h) simp))))))


(t/deftest commands
  (t/is (= "def double (n : Nat) : Nat := (n + n)" (dsl/command '(def double [n Nat] Nat (+ n n)))))
  (t/is (= "def answer := 42" (dsl/command '(def answer [] 42))))
  (t/is (= "@[simp] partial def f {α : Type} [BEq α] (x : α) : Bool := (x == x)"
           (dsl/command '(def ^{:attrs [simp] :partial true} f [(implicit α Type) (inst (BEq α)) x α] Bool (== x x)))))
  (t/is (= "theorem t (n : Nat) : (n = n) := rfl" (dsl/command '(theorem t [n Nat] (= n n) rfl))))
  (t/is (= "structure P where\n  x : Nat\n  y : Int\n  deriving Repr"
           (dsl/command '(structure P [x Nat y Int] (deriving Repr)))))
  (t/is (= "structure Pair (α : Type) where\n  fst : α\n  snd : α"
           (dsl/command '(structure Pair [α Type] [fst α snd α]))))
  (t/is (= "inductive Shape where\n  | circle (r : Nat)\n  | dot\n  deriving Repr, BEq"
           (dsl/command '(inductive Shape (circle [r Nat]) dot (deriving Repr BEq)))))
  (t/is (= "instance : Inhabited P := ⟨0, 0⟩" (dsl/command '(instance (Inhabited P) (<> 0 0)))))
  (t/is (= "mutual\ndef a := 1\ndef b := 2\nend" (dsl/command '(mutual (def a [] 1) (def b [] 2)))))
  (t/is (= "namespace N\n\ndef a := 1\n\nend N" (dsl/command '(namespace N (def a [] 1))))))
