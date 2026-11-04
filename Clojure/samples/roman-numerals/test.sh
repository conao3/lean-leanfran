#!/usr/bin/env bash
# Call the generated namespace from Clojure and compare with expected.txt.
set -euo pipefail
cd "$(dirname "$0")"
clojure -M -e "
(require '[roman.core :as roman])
(prn (roman/to-roman 1994))
(prn (roman/from-roman \"MMXXVI\"))
(prn (roman/from-roman \"hello\"))
(prn (map roman/to-roman (range 1 11)))
" | diff -u expected.txt -
echo "roman-numerals: output matches expected.txt"
