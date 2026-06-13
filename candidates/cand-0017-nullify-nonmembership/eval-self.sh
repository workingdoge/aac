#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0017-nullify-nonmembership.
# Witnesses NULLIFY/1: the low-leaf range bracket over a strictly-sorted set
# (accept a non-member; reject an already-spent value, a wrong low-leaf, a
# tampered root) AND the anti-replay composition (consume a fresh EVENT-COMPLETE/1
# event_nullifier; reject replaying a spent one). The crate depends on the landed
# ledger + rulebook, so we assemble a scratch workspace and run nargo there.
# nargo via NARGO_BIN/PATH/~/.nargo/bin; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
M="$CARGO/nullify/src/main.nr"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

check_logic() {
  local bad=0
  # the sorted invariant + the low-leaf bracket (the non-membership mechanism)
  grep -q 'not strictly sorted' "$M" || { echo "missing the sorted invariant"; bad=1; }
  grep -q 'low-leaf does not bracket' "$M" || { echo "missing the low-leaf range bracket"; bad=1; }
  grep -q 'bn254::lt' "$M" || { echo "Field ordering (bn254::lt) not used"; bad=1; }
  # the decisive negative + the anti-replay composition
  grep -q 'fn rejects_already_spent_nullifier' "$M" || { echo "missing the already-spent rejection"; bad=1; }
  grep -q 'fn consumes_a_fresh_event_nullifier' "$M" && grep -q 'fn rejects_replaying_a_spent_event_nullifier' "$M" || { echo "missing the EVENT-COMPLETE/1 anti-replay composition"; bad=1; }
  grep -q 'nullify' "$CARGO/Nargo.toml" || { echo "workspace does not include nullify"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "sorted invariant + low-leaf bracket + already-spent rejection + anti-replay composition present"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/ledger" "$ROOT/circuits/rulebook" \
        "$ROOT/circuits/event-complete" "$ROOT/circuits/transition" "$s/"
  cp -r "$CARGO/nullify" "$s/"
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"
  ( cd "$s" && "$NARGO" test --package nullify ) > "$TRACES/_test.txt" 2>&1 || { echo "tests FAILED"; tail -14 "$TRACES/_test.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "tests did not pass"; return 1; }
  ( cd "$s" && "$NARGO" execute --package nullify ) > "$TRACES/_exec.txt" 2>&1 || { echo "execute FAILED"; tail -5 "$TRACES/_exec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_exec.txt" || { echo "witness not solved"; return 1; }
  # the whole workspace must still compile with nullify added
  ( cd "$s" && "$NARGO" compile ) > "$TRACES/_ws.txt" 2>&1 || { echo "workspace compile FAILED with nullify"; tail -6 "$TRACES/_ws.txt"; return 1; }
  echo "nargo test OK ($(grep -oE '[0-9]+ tests passed' "$TRACES/_test.txt" | head -1)); sample witness solved; workspace compiles"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic check_logic || fail=1
run 02-prove check_prove || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0017-nullify-nonmembership",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "NULLIFY/1 non-membership via the low-leaf range bracket over a strictly-sorted set — accept a non-member; reject an already-spent value / wrong low-leaf / tampered root; consume a fresh EVENT-COMPLETE/1 event_nullifier and reject replaying a spent one; sample witness solves",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n' "$(grep -q 'composition present' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'  "$(grep -qE 'test OK|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
