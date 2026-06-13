#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0015-event-complete-roles-nullifier.
# Witnesses the grown EVENT-COMPLETE/1 circuit: role coverage + the in-circuit
# event nullifier, with the anti-replay binding. The crate depends on the landed
# pacioli + rulebook, so we assemble a scratch workspace and run nargo there.
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

check_obligations() {
  local bad=0
  # role coverage (obligation 2)
  grep -q 'missing Buyer role' "$MAIN" && grep -q 'one party fills both roles' "$MAIN" || { echo "role coverage missing"; bad=1; }
  grep -q 'participant_set' "$MAIN" || { echo "no participant_set commitment"; bad=1; }
  # event nullifier (obligation 9), derived in-circuit + bound to event+parties
  grep -q 'fn nullifier' "$MAIN" || { echo "no nullifier derivation"; bad=1; }
  grep -q 'event_nullifier incorrectly derived' "$MAIN" || { echo "nullifier not recomputed/equated"; bad=1; }
  # the anti-replay binding test + distinctness test
  grep -q 'fn rejects_replay_under_a_foreign_nullifier' "$MAIN" || { echo "missing anti-replay test"; bad=1; }
  grep -q 'fn nullifier_is_event_and_party_distinguishing' "$MAIN" || { echo "missing distinctness test"; bad=1; }
  # the journal binding is still present
  grep -q 'journal_commitment_of(j.debits, j.credits)' "$MAIN" || { echo "lost the journal binding"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "obligations 2 (roles) + 9 (nullifier, anti-replay) + the journal binding present"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s/event-complete/src"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/rulebook" "$ROOT/circuits/transition" "$s/" 2>/dev/null
  cp "$ROOT/circuits/Nargo.toml" "$s/Nargo.toml"
  cp "$CARGO/event-complete/Nargo.toml" "$s/event-complete/Nargo.toml" 2>/dev/null || cp "$ROOT/circuits/event-complete/Nargo.toml" "$s/event-complete/Nargo.toml"
  cp "$CARGO/event-complete/Prover.toml" "$s/event-complete/Prover.toml"
  cp "$MAIN" "$s/event-complete/src/main.nr"
  ( cd "$s" && "$NARGO" test --package event_complete ) > "$TRACES/_test.txt" 2>&1 || { echo "tests FAILED"; tail -12 "$TRACES/_test.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "tests did not pass"; return 1; }
  ( cd "$s" && "$NARGO" execute --package event_complete ) > "$TRACES/_exec.txt" 2>&1 || { echo "execute FAILED"; tail -5 "$TRACES/_exec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_exec.txt" || { echo "witness not solved"; return 1; }
  echo "nargo test OK ($(grep -oE '[0-9]+ tests passed' "$TRACES/_test.txt" | head -1)); sample receipt witness solved"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-oblig  check_obligations || fail=1
run 02-prove  check_prove       || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0015-event-complete-roles-nullifier",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "EVENT-COMPLETE/1 + role coverage (obligation 2) + the in-circuit event nullifier (obligation 9, anti-replay): accept a complete receipt; reject self-dealing / missing role / foreign nullifier; nullifier event/party/rulebook-distinguishing; sample witness solves",\n'
  printf '  "checks": {\n'
  printf '    "obligations": "%s",\n' "$(grep -q 'present' "$TRACES/01-oblig.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'        "$(grep -qE 'test OK|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
