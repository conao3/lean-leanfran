#!/usr/bin/env bash
# Diff-test: run LeanPythonTest.Vectors.report and LeanPythonTest.Io.run on the native C
# backend and on the generated Python, and compare stdout and stderr.
set -euo pipefail
ulimit -s 65536
export LEAN_BACKTRACE=0
export LEAN_PYTHON_TEST_VAR=from-the-environment
lake build lean-python oracle oracle-io LeanPythonTest
mkdir -p test-out
generate() {
  .lake/build/bin/lean-python module generate \
    --module-name "$1" --roots "$2" \
    --search-path .lake/build/lib/lean \
    --output-file "$3" --output text --internal-only
}
generate LeanPythonTest.Vectors LeanPythonTest.Vectors.report test-out/vectors.py
generate LeanPythonTest.Io LeanPythonTest.Io.run test-out/io.py
.lake/build/bin/oracle > test-out/oracle.txt 2> test-out/oracle.err
.lake/build/bin/oracle-io < /dev/null > test-out/io-oracle.txt 2> test-out/io-oracle.err
uv run python tests/difftest.py test-out/vectors.py l_LeanPythonTest_Vectors_report report > test-out/python.txt 2> test-out/python.err
uv run python tests/difftest.py test-out/io.py l_LeanPythonTest_Io_run io < /dev/null > test-out/io-python.txt 2> test-out/io-python.err
diff -u test-out/oracle.txt test-out/python.txt
diff -u test-out/oracle.err test-out/python.err
diff -u test-out/io-oracle.txt test-out/io-python.txt
diff -u test-out/io-oracle.err test-out/io-python.err
echo "diff-test: $(wc -l < test-out/oracle.txt) + $(wc -l < test-out/io-oracle.txt) lines match"
