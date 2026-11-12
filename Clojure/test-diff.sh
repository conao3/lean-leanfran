#!/usr/bin/env bash
# Diff-test: run LeanCljTest.Vectors.report on the native C backend and on the
# generated Clojure, and compare the output.
set -euo pipefail
ulimit -s 65536
lake build lean-clj oracle LeanCljTest
mkdir -p test-out/lean_clj_test
.lake/build/bin/lean-clj module generate-namespace \
  --module-name LeanCljTest.Vectors --namespace lean-clj-test.vectors \
  --roots LeanCljTest.Vectors.report --search-path .lake/build/lib/lean \
  --output-file test-out/lean_clj_test/vectors.clj --output text
.lake/build/bin/oracle > test-out/oracle.txt
clojure -M:test-out -e "(require 'lean-clj-test.vectors) (println (lean-clj-test.vectors/report nil))" > test-out/clojure.txt
diff -u test-out/oracle.txt test-out/clojure.txt
echo "diff-test: $(wc -l < test-out/oracle.txt) lines match"
