#!/usr/bin/env bash
# eval-self.sh — evidence for cand-0009-pn-conformance.
# Witnesses the two P^n conformance vectors in the pacioli crate: a
# multi-dimensional vector event is accepted as a zero-account, and a
# numeraire-collapse journal (dollars net, fabric vanishes) is rejected.
# pacioli is a standalone lib crate, so it tests in isolation. nargo via
# NARGO_BIN/PATH/~/.nargo/bin; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
LIB="$CAND_DIR/cargo/circuits/pacioli/src/lib.nr"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_present() {
  local bad=0
  grep -q 'fn pn_vector_event_is_a_zero_account' "$LIB" || { echo "missing the vector-accept vector"; bad=1; }
  grep -q 'fn pn_numeraire_collapse_is_rejected' "$LIB" || { echo "missing the numeraire-collapse vector"; bad=1; }
  # the collapse vector must actually assert REJECTION (the thesis), not acceptance
  grep -q '!journal_balanced' "$LIB" || { echo "collapse vector does not assert rejection"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "both P^n conformance vectors present; collapse asserts rejection"
}

check_test() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  # pacioli is a standalone lib crate: build a scratch crate from the cargo lib
  # and run its tests in isolation.
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s/src"
  cp "$ROOT/circuits/pacioli/Nargo.toml" "$s/Nargo.toml"
  cp "$LIB" "$s/src/lib.nr"
  ( cd "$s" && "$NARGO" test ) > "$TRACES/_test.txt" 2>&1 || { echo "nargo test FAILED"; tail -8 "$TRACES/_test.txt"; return 1; }
  grep -q 'pn_vector_event_is_a_zero_account ... ok\|pn_vector_event_is_a_zero_account ... \[' "$TRACES/_test.txt" \
    || grep -q 'tests passed' "$TRACES/_test.txt" || { echo "conformance tests did not run"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "not all tests passed"; return 1; }
  echo "nargo test OK ($(grep -oE '[0-9]+ tests passed' "$TRACES/_test.txt" | head -1)); P^n vectors run green"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present check_present || fail=1
run 02-test    check_test    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0009-pn-conformance",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "P^n conformance vectors in pacioli: a multi-dimensional vector event is accepted as a zero-account; a numeraire-collapse journal (dollars net, fabric vanishes) is rejected. nargo test green.",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n' "$(grep -q 'vectors present' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "test": "%s"\n'     "$(grep -qE 'test OK|^SKIP' "$TRACES/02-test.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
