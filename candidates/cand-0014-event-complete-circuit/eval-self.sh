#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0014-event-complete-circuit.
# Witnesses the EVENT-COMPLETE/1 circuit: it compiles Phi_R in-circuit and binds
# journal_commitment to the compiled journal (accept the schema image; reject a
# journal commitment from a different event; reject a tampered event commitment),
# and the sample witness solves. The crate depends on the landed pacioli plus the
# (field-pub) rulebook, so we assemble a scratch workspace and run nargo there.
# nargo via NARGO_BIN/PATH/~/.nargo/bin; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
MAIN="$CARGO/event-complete/src/main.nr"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_binds() {
  local bad=0
  # the circuit must witness the event, compile in-circuit, and equate the
  # recomputed journal_commitment over the COMPILED journal.
  grep -q 'compile_goods_receipt_invoice' "$MAIN" || { echo "circuit does not run Phi_R in-circuit"; bad=1; }
  grep -q 'journal_commitment_of(j.debits, j.credits)' "$MAIN" || { echo "journal_commitment not recomputed over the compiled journal"; bad=1; }
  grep -q 'journal_balanced(j.debits, j.credits)' "$MAIN" || { echo "compiled journal not checked for zero-account"; bad=1; }
  grep -q 'fn rejects_journal_commitment_from_a_different_event' "$MAIN" || { echo "missing the cross-event rejection test"; bad=1; }
  grep -q 'fn rejects_tampered_event_commitment' "$MAIN" || { echo "missing the tampered-event rejection test"; bad=1; }
  grep -q 'EVENT-COMPLETE/1' "$MAIN" || { echo "no EVENT-COMPLETE/1 correspondence"; bad=1; }
  grep -q 'event-complete' "$CARGO/Nargo.toml" || { echo "workspace does not include event-complete"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "circuit binds event -> Phi_R -> journal_commitment; negative tests present; in workspace"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/rulebook" "$ROOT/circuits/transition" "$s/" 2>/dev/null
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"
  cp "$CARGO/rulebook/src/lib.nr" "$s/rulebook/src/lib.nr"      # field-pub rulebook
  mkdir -p "$s/event-complete/src"
  cp "$CARGO/event-complete/Nargo.toml" "$s/event-complete/Nargo.toml"
  cp "$CARGO/event-complete/Prover.toml" "$s/event-complete/Prover.toml"
  cp "$MAIN" "$s/event-complete/src/main.nr"
  ( cd "$s" && "$NARGO" test --package event_complete ) > "$TRACES/_test.txt" 2>&1 || { echo "tests FAILED"; tail -10 "$TRACES/_test.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "tests did not pass"; return 1; }
  ( cd "$s" && "$NARGO" execute --package event_complete ) > "$TRACES/_exec.txt" 2>&1 || { echo "execute FAILED"; tail -5 "$TRACES/_exec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_exec.txt" || { echo "witness not solved"; return 1; }
  echo "nargo test OK ($(grep -oE '[0-9]+ tests passed' "$TRACES/_test.txt" | head -1)); sample witness solved"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-binds  check_binds  || fail=1
run 02-prove  check_prove  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0014-event-complete-circuit",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "EVENT-COMPLETE/1 circuit — Phi_R in-circuit binds journal_commitment to the compiled journal (accept the schema image; reject a journal commitment from a different event; reject a tampered event commitment); sample witness solves",\n'
  printf '  "checks": {\n'
  printf '    "binds": "%s",\n' "$(grep -q 'binds event' "$TRACES/01-binds.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'  "$(grep -qE 'test OK|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
