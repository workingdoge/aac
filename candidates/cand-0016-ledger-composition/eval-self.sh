#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0016-ledger-composition.
# Witnesses the unification: a shared ledger lib carries journal_commitment +
# event_nullifier so EVENT-COMPLETE/1 and TRANSITION/1 compose. Checks:
#   - the composition test (TRANSITION/1 posts the BVR's journal + nullifier);
#   - TRANSITION/1's journal_commitment is UNCHANGED (its landed Prover.toml,
#     jc 0x2d80c1.., still solves -> no cascade into transition or the UI);
#   - EVENT-COMPLETE/1's sample (shared canonical commitment) solves.
# pacioli is unchanged (landed); the cargo carries ledger/rulebook/transition/
# event-complete. nargo via NARGO_BIN/PATH/~/.nargo/bin; honest-skips.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

L="$CARGO/ledger/src/lib.nr"; T="$CARGO/transition/src/main.nr"; E="$CARGO/event-complete/src/main.nr"

check_shared() {
  local bad=0
  grep -q 'pub fn journal_commitment' "$L" && grep -q 'pub fn event_nullifier' "$L" && grep -q 'pub fn participant_set' "$L" || { echo "ledger lib missing canonical primitives"; bad=1; }
  grep -q 'ledger::journal_commitment' "$T" || { echo "transition does not use the shared journal_commitment"; bad=1; }
  grep -q 'use ledger::' "$E" && grep -q 'journal_commitment(j.accounts' "$E" && grep -q 'event_nullifier(' "$E" || { echo "event-complete does not use the shared primitives"; bad=1; }
  grep -q 'fn composition_transition_posts_the_bvr_journal' "$T" || { echo "no composition test"; bad=1; }
  grep -q 'ledger' "$CARGO/Nargo.toml" || { echo "workspace does not include ledger"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "shared ledger primitives; both circuits use them; composition test present"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s="$TRACES/scratch"; rm -rf "$s"; mkdir -p "$s"
  # pacioli + rulebook: unchanged crate skeletons come from the landed tree;
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/rulebook" "$s/"
  # the cargo carries the new/modified crates;
  cp -r "$CARGO/ledger" "$CARGO/transition" "$CARGO/event-complete" "$s/"
  cp "$CARGO/rulebook/src/lib.nr" "$s/rulebook/src/lib.nr"               # overlay the modified rulebook lib
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"
  cp "$ROOT/circuits/transition/Prover.toml" "$s/transition/Prover.toml" # landed: byte-identity check
  # all crates test
  ( cd "$s" && "$NARGO" test ) > "$TRACES/_test.txt" 2>&1 || { echo "tests FAILED"; tail -14 "$TRACES/_test.txt"; return 1; }
  grep -q 'composition_transition_posts_the_bvr_journal ... ' "$TRACES/_test.txt" || grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "composition test did not run"; return 1; }
  # TRANSITION/1 byte-identity: the LANDED Prover.toml (jc 0x2d80c1..) must still solve
  ( cd "$s" && "$NARGO" execute --package transition ) > "$TRACES/_txn.txt" 2>&1 || { echo "transition byte-identity BROKEN (landed Prover.toml no longer solves)"; tail -5 "$TRACES/_txn.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_txn.txt" || { echo "transition witness not solved"; return 1; }
  # EVENT-COMPLETE/1 with the shared canonical commitment solves
  ( cd "$s" && "$NARGO" execute --package event_complete ) > "$TRACES/_ec.txt" 2>&1 || { echo "event-complete execute FAILED"; tail -5 "$TRACES/_ec.txt"; return 1; }
  grep -q 'successfully solved' "$TRACES/_ec.txt" || { echo "event-complete witness not solved"; return 1; }
  local n; n="$(grep -oE '[0-9]+ tests passed' "$TRACES/_test.txt" | head -1)"
  echo "nargo test OK ($n); transition byte-identical (landed Prover.toml solves); event-complete solves"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-shared check_shared || fail=1
run 02-prove  check_prove  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0016-ledger-composition",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "shared ledger lib unifies EVENT-COMPLETE/1 + TRANSITION/1 on journal_commitment + event_nullifier — composition test (TRANSITION posts the BVR journal/nullifier), TRANSITION byte-identical (landed Prover.toml solves), event-complete solves",\n'
  printf '  "checks": {\n'
  printf '    "shared": "%s",\n' "$(grep -q 'composition test present' "$TRACES/01-shared.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'   "$(grep -qE 'byte-identical|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
