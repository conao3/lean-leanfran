#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/test-out/verify"
lts=("$root/../../.lake/build/bin/leanfran" --lang typescript)

fail() {
  printf 'test/verify: %s\n' "$*" >&2
  exit 1
}

scene() {
  local name="$1" from="$2"
  rm -rf "${out:?}/$name"
  mkdir -p "$out"
  cp -r "$from" "$out/$name"
  mkdir -p "$out/$name/node_modules"
  ln -sfn ../../../.. "$out/$name/node_modules/leanfran"
  ln -sfn ../../../../node_modules/zod "$out/$name/node_modules/zod"
}

expect_rows() {
  local got="$1" want="$2" what="$3"
  if ! diff <(printf '%s\n' "$want") <(printf '%s\n' "$got" | grep '^src/calc.ts:'); then
    fail "$what: unexpected obligation states"
  fi
}

base_rows="src/calc.ts:addOne [refines]: proved
src/calc.ts:clamp [inRange]: proved
src/calc.ts:clamp [refines]: proved
src/calc.ts:firstOr [refines]: proved
src/calc.ts:sumAbs [nonneg]: proved
src/calc.ts:sumTo [refines]: sorry
src/calc.ts:sumTo [returnsNat]: missing
src/calc.ts:twice [refines]: axioms"

scene base "$root/test/verify/app"
rm -rf "$out/base/node_modules/leanfran" "$out/base/src/_lean" "$out/base/.leanfran" "$out/base/leanfran.lock" "$out/base/leanfran.manifest.json"
ln -sfn ../../../.. "$out/base/node_modules/leanfran"
rows="$(cd "$out/base" && "${lts[@]}" check --package . 2>"$out/base.stderr")"
expect_rows "$rows" "$base_rows" "check"
[[ "$(grep -c 'blocks checked and generated' "$out/base.stderr")" == 2 ]] || fail "the first check did not generate again once after the proved refines changed LeanTsCsimp"
more_rows="src/more.ts:area [refines]: proved
src/more.ts:code [refines]: proved
src/more.ts:countDown [refines]: missing
src/more.ts:describe [refines]: proved
src/more.ts:evens [refines]: missing
src/more.ts:firstPositive [refines]: missing
src/more.ts:label [refines]: proved
src/more.ts:manhattan [refines]: missing
src/more.ts:nonNeg [refines]: missing
src/more.ts:safeDiv [refines]: missing
src/more.ts:shift [refines]: proved
src/more.ts:sumSquares [refines]: missing
src/more.ts:swap [refines]: proved
src/more.ts:tag [refines]: missing"
diff <(printf '%s\n' "$more_rows") <(printf '%s\n' "$rows" | grep '^src/more.ts:') || fail "check: unexpected states of more.ts"
orders_rows="src/orders.ts:hasNote [refines]: missing
src/orders.ts:lineTotal [refines]: proved
src/orders.ts:quantity [positive]: proved"
diff <(printf '%s\n' "$orders_rows") <(printf '%s\n' "$rows" | grep '^src/orders.ts:') || fail "check: unexpected states of orders.ts (the zod constraint qty >= 1 is an assumption of quantity)"
got="$(cd "$out/base" && node --input-type=module -e 'const s = await import("./src/_lean/more.ts"); console.log(String(s.area({ ctor: "rect", w: 3n, h: 4n })), String(s.code("blue")), s.swap([1n, 2n]).map(String).join(","))')"
[[ "$got" == '12 3 2,1' ]] || fail "the specs of more.ts through the TypeScript functions printed: $got"
[[ -f "$out/base/leanfran.lock" ]] || fail "check did not write leanfran.lock"
grep -q '"hash"' "$out/base/leanfran.lock" || fail "the lock has no hash"
snapshot() {
  (cd "$1" && find . -path ./node_modules -prune -o -path ./.leanfran/typescript -prune -o -type f -print0 | sort -z | xargs -0 sha256sum)
}
before="$(snapshot "$out/base")"
(cd "$out/base" && "${lts[@]}" check --package . >/dev/null 2>"$out/base-again.stderr")
[[ "$(grep -c 'blocks checked and generated' "$out/base-again.stderr")" == 1 ]] || fail "a second check generated again"
[[ "$(snapshot "$out/base")" == "$before" ]] || fail "a second check changed a file"

set +e
(cd "$out/base" && "${lts[@]}" check --package . --require proved >/dev/null 2>&1)
code=$?
set -e
[[ $code -eq 1 ]] || fail "check --require proved exited with $code, expected 1"

rows="$(cd "$out/base" && "${lts[@]}" status --package .)"
expect_rows "$rows" "$base_rows" "status"

grep -q '$s0.addOne(L.tsNumbers(' "$out/base/src/_lean/calc__spec.ts" || fail "the proved refines of addOne did not make succ call the TypeScript function"
grep -q '$s0.clamp(' "$out/base/src/_lean/calc__spec.ts" && fail "clamp has a requires and must not replace clampSpec"
got="$(cd "$out/base" && node --input-type=module -e 'await import("./src/calc.ts"); const s = await import("./src/_lean/calc.ts"); console.log(String(s.succTwice(1)), String(s.succ(41n)))')"
[[ "$got" == "3 42" ]] || fail "succTwice through the TypeScript addOne printed: $got"
got="$(cd "$out/base" && node --input-type=module -e 'const s = await import("./src/_lean/calc.ts"); console.log(String(s.succTwice(1)))')"
[[ "$got" == "3" ]] || fail "importing the generated module before the TypeScript module printed: $got"

scene csimp-off "$out/base"
sed -i 's/^  simp \[addOne, LeanTsEmbed.calc.spec.succ\]$/  sorry/' "$out/csimp-off/lean/Proofs/Calc.lean"
(cd "$out/csimp-off" && "${lts[@]}" check --package . >/dev/null 2>&1)
grep -q '$s0.addOne(' "$out/csimp-off/src/_lean/calc__spec.ts" && fail "a sorry refines still replaced the specification"
grep -q '"sorry"' "$out/csimp-off/leanfran.lock" || fail "the lock of csimp-off has no sorry"

scene stale "$out/base"
sed -i 's/  if (x > hi) return hi/  if (x >= hi) return hi/' "$out/stale/src/calc.ts"
sed -i 's/^export function clamp/\/\/ moved down by a line\nexport function clamp/' "$out/stale/src/calc.ts"
set +e
rows="$(cd "$out/stale" && "${lts[@]}" status --package .)"
code=$?
set -e
[[ $code -eq 1 ]] || fail "status of a changed function exited with $code, expected 1"
expect_rows "$rows" "src/calc.ts:addOne [refines]: proved
src/calc.ts:clamp [inRange]: stale
src/calc.ts:clamp [refines]: stale
src/calc.ts:firstOr [refines]: proved
src/calc.ts:sumAbs [nonneg]: proved
src/calc.ts:sumTo [refines]: sorry
src/calc.ts:sumTo [returnsNat]: missing
src/calc.ts:twice [refines]: axioms" "status after a change"

scene moved "$out/base"
sed -i 's/^export function clamp/\/\/ a comment above the function\nexport function clamp/' "$out/moved/src/calc.ts"
rows="$(cd "$out/moved" && "${lts[@]}" status --package .)"
expect_rows "$rows" "$base_rows" "status after moving a function"

scene wrong-proof "$out/base"
proofs="$out/wrong-proof/lean/Proofs/Calc.lean"
sed -i 's/^theorem firstOr.proof.refines : firstOr.obligation.refines := by$/theorem firstOr.proof.refines : True := trivial\n\ntheorem firstOr.unused : firstOr.obligation.refines := by/' "$proofs"
cat >"$out/wrong-proof/lean/Proofs/Broken.lean" <<'EOF'
import LeanTsModel.calc

theorem LeanTsModel.calc.sumTo.proof.returnsNat : LeanTsModel.calc.sumTo.obligation.returnsNat := by
  intro n
  rfl
EOF
code=0
rows="$(cd "$out/wrong-proof" && "${lts[@]}" check --package . 2>/dev/null)" || code=$?
[[ $code -eq 1 ]] || fail "check with a failing proof exited with $code, expected 1"
expect_rows "$rows" "src/calc.ts:addOne [refines]: proved
src/calc.ts:clamp [inRange]: proved
src/calc.ts:clamp [refines]: proved
src/calc.ts:firstOr [refines]: mismatch
src/calc.ts:sumAbs [nonneg]: proved
src/calc.ts:sumTo [refines]: sorry
src/calc.ts:sumTo [returnsNat]: failed
src/calc.ts:twice [refines]: axioms" "check with a wrong statement and a failing proof"

scene outside "$out/base"
cat >>"$out/outside/src/calc.ts" <<'EOF'

export function loose(x: number): boolean {
  return x == 1
}

model(loose, { ensures: { nonneg: spec.nonneg } })
EOF
set +e
msg="$(cd "$out/outside" && "${lts[@]}" check --package . 2>&1 >/dev/null)"
code=$?
set -e
[[ $code -eq 1 ]] || fail "check of a function outside the subset exited with $code, expected 1"
grep -q 'src/calc.ts:[0-9]*:[0-9]*: unextracted src/calc.ts:loose: == is outside the subset' <<<"$msg" || fail "no position for the untranslatable function: $msg"

scene wrong-impl "$out/base"
cat >"$out/wrong-impl/wrong.ts" <<'EOF'
import { checkModel, model, PropertyFailure } from "leanfran/verify"
import * as spec from "./src/_lean/calc.ts"

function badClamp(x: number, lo: number, _hi: number): number {
  if (x < lo) return lo
  return x
}

model(badClamp, { refines: spec.clampSpec, requires: spec.ordered })

try {
  await checkModel(badClamp)
  console.log("no counterexample")
} catch (e) {
  if (!(e instanceof PropertyFailure)) throw e
  console.log(e.message.includes("the spec gives") ? "counterexample" : e.message)
}
EOF
got="$(cd "$out/wrong-impl" && node wrong.ts)"
[[ "$got" == counterexample ]] || fail "checkModel of a wrong implementation printed: $got"

printf 'test/verify: ok\n'
