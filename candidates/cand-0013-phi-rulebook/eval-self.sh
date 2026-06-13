#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0013-phi-rulebook.
# Witnesses the Phi_R compiler: it reproduces the Pⁿ conformance vector exactly
# and compiles to a zero-account for all quantities. rulebook depends on the
# landed pacioli crate, so we assemble a scratch workspace (landed pacioli +
# transition + the cargo rulebook + the cargo workspace toml) and run nargo
# there. nargo via NARGO_BIN/PATH/~/.nargo/bin; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
LIB="$CARGO/rulebook/src/lib.nr"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_derives() {
  local bad=0
  grep -q 'fn compile_goods_receipt_invoice' "$LIB" || { echo "no compile_goods_receipt_invoice"; bad=1; }
  grep -q 'fn phi_reproduces_the_conformance_vector' "$LIB" || { echo "no conformance-reproduction test"; bad=1; }
  grep -q 'fn phi_is_balanced_for_all_quantities' "$LIB" || { echo "no balanced-for-all test"; bad=1; }
  # it must reproduce the cand-0009 conformance vector (same expected journal)
  grep -q '\[10000, 0, 0\]' "$LIB" && grep -q '\[0, 50, 0\]' "$LIB" || { echo "expected conformance journal not present"; bad=1; }
  grep -q 'EVENT-COMPLETE/1' "$LIB" || { echo "no EVENT-COMPLETE/1 correspondence"; bad=1; }
  # the workspace toml must include rulebook
  grep -q 'rulebook' "$CARGO/Nargo.toml" || { echo "workspace does not include rulebook"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "compiler + both Phi_R tests present; reproduces the conformance journal; in workspace"
}

check_test() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s/rulebook/src"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/transition" "$s/" 2>/dev/null
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"
  cp "$CARGO/rulebook/Nargo.toml" "$s/rulebook/Nargo.toml"
  cp "$LIB" "$s/rulebook/src/lib.nr"
  # rulebook tests (the Phi_R properties)
  ( cd "$s" && "$NARGO" test --package rulebook ) > "$TRACES/_rb.txt" 2>&1 || { echo "rulebook tests FAILED"; tail -8 "$TRACES/_rb.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_rb.txt" || { echo "rulebook tests did not pass"; return 1; }
  # the whole workspace must still compile with rulebook added
  ( cd "$s" && "$NARGO" compile ) > "$TRACES/_ws.txt" 2>&1 || { echo "workspace compile FAILED with rulebook"; tail -6 "$TRACES/_ws.txt"; return 1; }
  echo "nargo test OK ($(grep -oE '[0-9]+ tests passed' "$TRACES/_rb.txt" | head -1)); workspace compiles with rulebook"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-derives check_derives || fail=1
run 02-test    check_test    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0013-phi-rulebook",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Phi_R goods-receipt-invoice compiler — reproduces the Pⁿ conformance vector exactly and compiles to a zero-account for all quantities (the journal is the schema image, not arbitrary entries); workspace compiles with the rulebook crate",\n'
  printf '  "checks": {\n'
  printf '    "derives": "%s",\n' "$(grep -q 'reproduces the conformance journal' "$TRACES/01-derives.txt" && echo pass || echo fail)"
  printf '    "test": "%s"\n'     "$(grep -qE 'test OK|^SKIP' "$TRACES/02-test.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
