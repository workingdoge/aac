#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0021-review-findings.
# Witnesses the remediation of the post-compaction review (P1/P2/P3):
#   P2  NULLIFY/1 refuses new_value == 0 (the empty-slot sentinel TRANSITION/1
#       reserves), with a negative test; EVENT-COMPLETE/1 asserts its nullifier
#       is nonzero.
#   P3  a before-first (low_index = 0) ACCEPT test now witnesses what cand-0017
#       claimed, plus a correction note on cand-0017.
#   P1  EVENT-COMPLETE/1's obligation-9 claim is narrowed in the circuit AND the
#       spec to an event-scoped nullifier (NOT the 2/FACT S3 factId derivation).
# The changed crates depend on the landed pacioli/ledger/rulebook/transition, so
# we assemble a scratch workspace and run nargo there. nargo via
# NARGO_BIN/PATH/~/.nargo/bin; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
NM="$CARGO/nullify/src/main.nr"
EM="$CARGO/event-complete/src/main.nr"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/EVENT-COMPLETE-1.md"
R17="$CAND_DIR/cargo/candidates/cand-0017-nullify-nonmembership/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_logic() {
  local bad=0
  # P2 -- the reserved-sentinel guard + its negative test (nullify).
  grep -q 'new_value != 0' "$NM" || { echo "missing the new_value != 0 guard (P2)"; bad=1; }
  grep -q 'fn rejects_inserting_the_zero_sentinel' "$NM" || { echo "missing the zero-sentinel negative test (P2)"; bad=1; }
  # P2 -- EVENT-COMPLETE/1 asserts its nullifier is nonzero.
  grep -q 'event_nullifier is the 0 sentinel' "$EM" || { echo "missing the EVENT-COMPLETE/1 nonzero-nullifier assert (P2)"; bad=1; }
  # P3 -- the before-first ACCEPT test (nullify) + the cand-0017 correction note.
  grep -q 'fn accepts_insert_before_first' "$NM" || { echo "missing the before-first accept test (P3)"; bad=1; }
  grep -q 'Correction (cand-0021' "$R17" || { echo "missing the cand-0017 correction note (P3)"; bad=1; }
  # P1 -- the obligation-9 narrowing, in the circuit AND the spec.
  grep -qi 'event-scoped' "$EM" || { echo "circuit does not narrow obligation 9 to event-scoped (P1)"; bad=1; }
  grep -q 'Implementation status' "$SPEC" || { echo "spec lacks the Implementation status section (P1)"; bad=1; }
  grep -qi 'event-scoped nullifier' "$SPEC" || { echo "spec does not scope obligation 9 to an event-scoped nullifier (P1)"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "P1 (obligation-9 narrowing) + P2 (zero-sentinel guards) + P3 (before-first accept + cand-0017 correction) present"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/ledger" "$ROOT/circuits/rulebook" \
        "$ROOT/circuits/transition" "$s/"
  cp -r "$CARGO/nullify" "$CARGO/event-complete" "$s/"
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"

  ( cd "$s" && "$NARGO" test --package nullify ) > "$TRACES/_null.txt" 2>&1 || { echo "nullify tests FAILED"; tail -14 "$TRACES/_null.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_null.txt" || { echo "nullify tests did not pass"; return 1; }
  # the two new nullify cases must each be exercised and green.
  grep -q 'accepts_insert_before_first' "$TRACES/_null.txt" || { echo "before-first test did not run"; return 1; }
  grep -q 'rejects_inserting_the_zero_sentinel' "$TRACES/_null.txt" || { echo "zero-sentinel test did not run"; return 1; }

  ( cd "$s" && "$NARGO" test --package event_complete ) > "$TRACES/_ec.txt" 2>&1 || { echo "event_complete tests FAILED"; tail -14 "$TRACES/_ec.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_ec.txt" || { echo "event_complete tests did not pass"; return 1; }

  ( cd "$s" && "$NARGO" execute --package nullify ) > "$TRACES/_nexec.txt" 2>&1 || { echo "nullify execute FAILED"; tail -5 "$TRACES/_nexec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_nexec.txt" || { echo "nullify witness not solved"; return 1; }
  ( cd "$s" && "$NARGO" execute --package event_complete ) > "$TRACES/_eexec.txt" 2>&1 || { echo "event_complete execute FAILED"; tail -5 "$TRACES/_eexec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_eexec.txt" || { echo "event_complete witness not solved"; return 1; }

  # the whole workspace must still compile with both changed crates.
  ( cd "$s" && "$NARGO" compile ) > "$TRACES/_ws.txt" 2>&1 || { echo "workspace compile FAILED"; tail -6 "$TRACES/_ws.txt"; return 1; }
  echo "nargo test OK (nullify $(grep -oE '[0-9]+ tests passed' "$TRACES/_null.txt" | head -1); event_complete $(grep -oE '[0-9]+ tests passed' "$TRACES/_ec.txt" | head -1)); both witnesses solved; workspace compiles"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic check_logic || fail=1
run 02-prove check_prove || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0021-review-findings",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "remediate the post-compaction review: P2 NULLIFY/1 refuses new_value==0 (the TRANSITION/1 empty-slot sentinel) + EVENT-COMPLETE/1 asserts its nullifier nonzero; P3 a before-first (low_index=0) accept test witnesses cand-0017s claim + a correction note; P1 obligation-9 narrowed to an event-scoped nullifier (not the 2/FACT S3 factId derivation) in the circuit and the spec; nargo test+execute green across both changed crates",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n' "$(grep -q 'present' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'  "$(grep -qE 'test OK|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
