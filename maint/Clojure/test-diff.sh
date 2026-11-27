#!/usr/bin/env bash
# Diff-test: run LeanCljTest.Vectors.report on the native C backend and on the
# generated Clojure, and compare the output.
set -euo pipefail
cd "$(dirname "$0")/../../langs/Clojure"
ulimit -s 65536
lake --dir ../.. build leanfran
lake build oracle LeanCljTest
mkdir -p test-out/leanfran_test
../../.lake/build/bin/leanfran --lang clojure module generate-namespace \
  --module-name LeanCljTest.Vectors --namespace leanfran-test.vectors \
  --roots LeanCljTest.Vectors.report --search-path .lake/build/lib/lean \
  --output-file test-out/leanfran_test/vectors.clj --output text
.lake/build/bin/oracle > test-out/oracle.txt
clojure -M:test-out -e "(require 'leanfran-test.vectors) (println (leanfran-test.vectors/report nil))" > test-out/clojure.txt
diff -u test-out/oracle.txt test-out/clojure.txt
echo "diff-test: $(wc -l < test-out/oracle.txt) lines match"
