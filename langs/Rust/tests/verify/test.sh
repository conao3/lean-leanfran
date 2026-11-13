#!/usr/bin/env bash
# cargo leanfran on copies of this crate: extract and check reproduce the committed files and
# states, a proof that does not build is failed, a change of a function, of a function it calls
# or of a spec makes its obligations stale, require = "proved" stops the build, a wrong spec path
# or argument type is a rustc error, the test of a refines catches a wrong implementation, and
# the test of an opaque function catches a wrong model.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
src="$root/tests/verify"
export LEANFRAN_CLI="${LEANFRAN_CLI:-$root/.lake/build/bin/leanfran}"
cargo build -q -p cargo-leanfran --manifest-path "$root/Cargo.toml"
clr="$root/target/debug/cargo-leanfran"
work="$root/test-out/verify"
rm -rf "$work"
mkdir -p "$work"
export CARGO_TARGET_DIR="$root/test-out/verify-target"

copy() {
  local d="$work/$1"
  mkdir -p "$d"
  (cd "$src" && cp -r Cargo.toml build.rs src tests lean leanfran.lock .leanfran "$d/")
  sed -i "s|path = \"../../crates/|path = \"$root/crates/|" "$d/Cargo.toml"
  printf '\n[workspace]\n' >>"$d/Cargo.toml"
  sed -i "s|^packagesDir = .*|packagesDir = \"$root/.lake-aeneas/packages\"|" "$d/lean/lakefile.toml"
  echo "$d"
}

fail() {
  echo "verify-test: $*" >&2
  exit 1
}

expect_status() {
  local d="$1" rust="$2" label="$3" status="$4"
  "$clr" leanfran status --manifest-path "$d/Cargo.toml" | awk -v r="$rust" -v l="$label" -v s="$status" '
    $0 == r { inside = 1; next }
    /^crate::/ { inside = 0 }
    inside && $1 == l { found = ($2 == s) }
    END { exit found ? 0 : 1 }' || fail "$rust $label is not $status in $d"
}

d=$(copy fresh)
(cd "$d" && cargo build 2>"$work/fresh.log")
if grep -q "leanfran:" "$work/fresh.log"; then
  fail "a build of the committed crate reports: $(cat "$work/fresh.log")"
fi
expect_status "$d" crate::arith::bigger refines proved
expect_status "$d" crate::arith::double refines sorry
expect_status "$d" crate::arith::halve halved missing
expect_status "$d" crate::arith::succ pos mismatch
expect_status "$d" crate::effects::guarded same axioms
expect_status "$d" crate::counter::Counter::reset refines proved
(cd "$d" && "$clr" leanfran extract >/dev/null && "$clr" leanfran check >/dev/null)
diff -r -I '^ *Source: ' "$src/lean/LeanRustGen" "$d/lean/LeanRustGen" ||
  fail "extract and check do not reproduce lean/LeanRustGen"
diff <(grep -v '^proof = ' "$src/leanfran.lock") <(grep -v '^proof = ' "$d/leanfran.lock") ||
  fail "extract and check do not reproduce leanfran.lock"
echo "verify-test: extract and check reproduce the committed model, obligations, csimp and lockfile"
cat >"$d/lean/Proofs/Halve.lean" <<'LEAN'
import LeanRustGen.Obligation.leanfran_verify_test.arith

theorem leanfran_verify_test.arith.halve.proof.halved :
    leanfran_verify_test.arith.halve.obligation.halved := by
  exact 0
LEAN
(cd "$d" && "$clr" leanfran check >/dev/null)
expect_status "$d" crate::arith::halve halved failed
expect_status "$d" crate::arith::bigger refines proved
echo "verify-test: a proof whose file does not build is failed, and the others are checked"

d=$(copy stale)
sed -i 's|    x / 2|    x / 4|' "$d/src/arith.rs"
sed -i 's|        a$|        a.max(b)|' "$d/src/arith.rs"
(cd "$d" && cargo build 2>"$work/stale.log")
grep -q "leanfran: crate::arith::halve: 1 obligation is stale (crate::arith::half changed" "$work/stale.log" ||
  fail "a change of a called function is not reported: $(cat "$work/stale.log")"
grep -q "leanfran: crate::arith::bigger: 1 obligation is stale (crate::arith::bigger changed" "$work/stale.log" ||
  fail "a change of a modelled function is not reported: $(cat "$work/stale.log")"
expect_status "$d" crate::arith::bigger refines stale
expect_status "$d" crate::arith::double refines sorry
sed -i 's|    def small (x : Std.U32) : Bool := decide (x.val < 1000)|    def small (x : Std.U32) : Bool := decide (x.val < 999)|' "$d/src/spec.rs"
(cd "$d" && cargo build 2>"$work/spec.log")
grep -q "leanfran: crate::arith::succ: 1 obligation is stale (a spec changed" "$work/spec.log" ||
  fail "a change of a spec is not reported: $(cat "$work/spec.log")"
sed -i "s|#\[leanfran::model(instances = \[u32, i64\], ensures|#[leanfran::model(instances = [u32], ensures|" "$d/src/generic.rs"
(cd "$d" && cargo build 2>"$work/instances.log")
grep -q "leanfran: crate::generic::max_of: 1 obligation is stale (.*instances of crate::generic::max_of changed" "$work/instances.log" ||
  fail "a change of the instances is not reported: $(cat "$work/instances.log")"
echo "verify-test: changes of a function, a called function and a spec make the obligations stale"

d=$(copy require)
if (cd "$d" && LEANFRAN_REQUIRE=proved cargo build -q 2>"$work/require.log"); then
  fail "LEANFRAN_REQUIRE=proved builds with unproved obligations"
fi
grep -q "crate::arith::double: refines (sorry)" "$work/require.log" || fail "require: $(cat "$work/require.log")"
grep -q "crate::effects::guarded: same (axioms)" "$work/require.log" || fail "require: $(cat "$work/require.log")"
printf '\n[package.metadata.leanfran]\nrequire = "proved"\n' >>"$d/Cargo.toml"
if (cd "$d" && cargo build -q 2>/dev/null); then
  fail "require = \"proved\" builds with unproved obligations"
fi
echo "verify-test: require = \"proved\" lists the obligations that are not proved"

d=$(copy wrong-path)
sed -i 's|refines = specs::double|refines = specs::doubled|' "$d/src/arith.rs"
if (cd "$d" && cargo build 2>"$work/wrong-path.log"); then
  fail "a spec path that does not exist compiles"
fi
grep -q "cannot find function \`doubled\` in module \`specs\`" "$work/wrong-path.log" ||
  fail "wrong path: $(cat "$work/wrong-path.log")"
d=$(copy wrong-type)
sed -i 's|ensures(halved = specs::halved)|ensures(halved = specs::all_zero)|' "$d/src/arith.rs"
if (cd "$d" && cargo build 2>"$work/wrong-type.log"); then
  fail "a spec of other argument types compiles"
fi
grep -q "expected \`Vec<u32>\`, found \`u32\`" "$work/wrong-type.log" || fail "wrong type: $(cat "$work/wrong-type.log")"
d=$(copy wrong-instance)
sed -i "s|#\[leanfran::model(instances = \[u32, i64\], ensures|#[leanfran::model(instances = [u32, u8], ensures|" "$d/src/generic.rs"
if (cd "$d" && cargo build 2>"$work/wrong-instance.log"); then
  fail "a type the spec is not instantiated for compiles"
fi
grep -q "the trait bound \`u8: spec::generic_specs::__leanfran_inst::MaxGe\` is not satisfied" "$work/wrong-instance.log" ||
  fail "wrong instance: $(cat "$work/wrong-instance.log")"
echo "verify-test: rustc rejects a wrong spec path and a spec of other argument types"

d=$(copy wrong-impl)
sed -i 's|        b$|        a|' "$d/src/arith.rs"
if (cd "$d" && cargo test -q --lib 2>"$work/wrong-impl.log" >"$work/wrong-impl.out"); then
  fail "the test of refines passes for a wrong implementation"
fi
grep -q "check_refines" "$work/wrong-impl.out" || fail "wrong impl: $(cat "$work/wrong-impl.out")"
grep -Eq "the function returned [0-9]+, and the spec specs::bigger returned [0-9]+" "$work/wrong-impl.out" ||
  fail "wrong impl message: $(cat "$work/wrong-impl.out")"
echo "verify-test: the test of a refines catches a wrong implementation"

d=$(copy wrong-model)
sed -i 's|else ok 100#u32|else ok 99#u32|' "$d/lean/External.lean"
if (cd "$d" && cargo test -q --lib 2>"$work/wrong-model.log" >"$work/wrong-model.out"); then
  fail "the test of an opaque function passes for a wrong model"
fi
grep -q "__leanfran_opaque_clamp::check_model" "$work/wrong-model.out" || fail "wrong model: $(cat "$work/wrong-model.out")"
echo "verify-test: the test of an opaque function catches a wrong model in lean/External.lean"

d=$(copy wrong-method-model)
sed -i 's|then ok self.value else ok limit|then ok limit else ok self.value|' "$d/lean/External.lean"
if (cd "$d" && cargo test -q --lib 2>"$work/wrong-method-model.log" >"$work/wrong-method-model.out"); then
  fail "the test of an opaque method passes for a wrong model"
fi
grep -q "__leanfran_opaque_Meter_lesser::check_model" "$work/wrong-method-model.out" ||
  fail "wrong method model: $(cat "$work/wrong-method-model.out")"
echo "verify-test: the test of an opaque method catches a wrong model in lean/External.lean"

d=$(copy opaque-method-clash)
cat >>"$d/src/effects.rs" <<'RS'

pub struct Gauge {
    pub value: u32,
}

impl Gauge {
    pub fn lesser(&self, limit: u32) -> u32 {
        self.value.min(limit)
    }
}
RS
if (cd "$d" && "$clr" leanfran extract >"$work/opaque-method-clash.out" 2>&1); then
  fail "extract makes an opaque method that shares its module and name with another method"
fi
grep -q "#\[leanfran::opaque\] method crate::effects::Meter::lesser: .*crate::effects::Gauge::lesser has the same" "$work/opaque-method-clash.out" ||
  fail "opaque method clash: $(cat "$work/opaque-method-clash.out")"
echo "verify-test: extract stops at an opaque method whose module and name another method shares"
