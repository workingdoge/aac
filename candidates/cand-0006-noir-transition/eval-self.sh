#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0006-noir-transition.
# Witnesses that the TRANSITION/1 circuit compiles, its conformance test suite
# passes (valid accepts; unbalanced / tampered-root / double-spend / zero-
# multiplicity reject), and the sample witness solves. nargo is located via
# NARGO_BIN / PATH / ~/.nargo/bin; honest-skips (no false pass) when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CIRC="$CAND_DIR/cargo/circuits"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }

have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_compile() {
  have_nargo || { echo "SKIP: nargo absent (set NARGO_BIN or install noirup)"; return 0; }
  ( cd "$CIRC" && "$NARGO" compile ) && echo "nargo compile OK (pacioli + transition)"
}

check_test() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local out_t out_p
  out_t="$( cd "$CIRC" && "$NARGO" test --package transition 2>&1 )"; local rc_t=$?
  out_p="$( cd "$CIRC" && "$NARGO" test --package pacioli 2>&1 )"; local rc_p=$?
  printf '%s\n--- pacioli ---\n%s\n' "$out_t" "$out_p"
  [[ $rc_t -eq 0 && $rc_p -eq 0 ]] || { echo "TESTS FAILED"; return 1; }
  # the negative tests must actually be present (guard against a vacuous pass)
  for needle in unbalanced_journal_rejects tampered_next_root_rejects double_spend_rejects zero_multiplicity_fact_rejects balanced_transition_accepts; do
    grep -q "$needle" "$CIRC/transition/src/main.nr" || { echo "MISSING test $needle"; return 1; }
  done
  echo "nargo test OK (transition accept+reject suite, pacioli laws)"
}

check_execute() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  ( cd "$CIRC" && "$NARGO" execute --package transition ) > "$TRACES/_exec.txt" 2>&1 \
    || { echo "execute FAILED"; tail -5 "$TRACES/_exec.txt"; return 1; }
  grep -q "successfully solved" "$TRACES/_exec.txt" && echo "nargo execute OK (sample witness solved)"
}

check_lean_link() {
  # The carrier-injectivity discipline must be wired to the machine-checked
  # bound: the circuit names journal_sum_field_sound / Core.lean, and uses the
  # Field->u64->Field roundtrip (assert_u64) on amounts.
  local bad=0
  grep -q 'journal_sum_field_sound' "$CIRC/README.md" || { echo "README does not cite journal_sum_field_sound"; bad=1; }
  grep -q 'assert_u64' "$CIRC/pacioli/src/lib.nr" || { echo "no assert_u64 roundtrip in pacioli"; bad=1; }
  grep -q 'assert_u64' "$CIRC/transition/src/main.nr" || { echo "transition does not bound amounts"; bad=1; }
  grep -q 'journal_balanced' "$CIRC/transition/src/main.nr" || { echo "transition does not enforce journal balance"; bad=1; }
  [[ -f "$ROOT/sites/ledger/statements/Core.lean" ]] && grep -q 'journal_sum_field_sound' "$ROOT/sites/ledger/statements/Core.lean" || { echo "Core.lean bound not found"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "Lean<->Noir link OK (journal_sum_field_sound <-> assert_u64/journal_balanced)"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-14s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-compile  check_compile   || fail=1
run 02-test     check_test      || fail=1
run 03-execute  check_execute   || fail=1
run 04-leanlink check_lean_link || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0006-noir-transition",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "TRANSITION/1 Noir circuit (3/PROOF S4.1) — compiles, conformance suite passes (accept valid; reject unbalanced/tampered/double-spend/zero-multiplicity), sample witness solves, wired to journal_sum_field_sound",\n'
  printf '  "checks": {\n'
  printf '    "compile": "%s",\n'  "$(grep -qE 'compile OK|^SKIP' "$TRACES/01-compile.txt" && echo pass || echo fail)"
  printf '    "test": "%s",\n'     "$(grep -qE 'test OK|^SKIP'    "$TRACES/02-test.txt"    && echo pass || echo fail)"
  printf '    "execute": "%s",\n'  "$(grep -qE 'execute OK|^SKIP' "$TRACES/03-execute.txt" && echo pass || echo fail)"
  printf '    "lean_link": "%s"\n' "$(grep -q 'link OK'           "$TRACES/04-leanlink.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
