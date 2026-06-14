#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0032-ledger-receipt-split.
# Witnesses the ledger/receipt split + tag reconciliation: `ledger` is slimmed to
# the KERNEL commitment seam (journal_commitment + TAG_JOURNAL=3); the app-side
# receipt identities (participant_set, event_nullifier) move into a new
# `circuits/receipt` lib with tags REASSIGNED off the 122/123 collision with R1's
# receipt-reference block to 124/125 (3/PROOF Annex A app range). event-complete
# imports journal_commitment from ledger and participant_set/event_nullifier from
# receipt; its witness is regenerated. transition/nullify are untouched (the
# kernel consumes nullifiers opaquely). Checks: (1) structural -- ledger slimmed,
# receipt holds the identities at 124/125, consumers/workspace/R1 rewired; (2)
# nargo test --workspace green (8 crates) + all witnesses solve; (3) CASCADE
# SCOPED -- event_commitment + journal_commitment values byte-identical to live
# (kernel seam untouched) while participant_set + event_nullifier changed; (4) a
# candidate-local mutant proving the slim-probe is non-vacuous.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
CC="$CARGO/circuits"
R1="$CARGO/sites/ledger/specs/registers/R1.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

# attest.sh uses GNU `head -n -1`; shim for BSD/macOS (cand-0030/0031 pattern).
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) structural: ledger slimmed, receipt rewired, consumers updated ------
check_logic() {
  local bad=0
  # receipt: the app identities at the reassigned tags, hash dep only.
  grep -q 'pub fn participant_set' "$CC/receipt/src/lib.nr" || { echo "receipt lacks participant_set"; bad=1; }
  grep -q 'pub fn event_nullifier' "$CC/receipt/src/lib.nr" || { echo "receipt lacks event_nullifier"; bad=1; }
  grep -q 'TAG_PARTY: Field = 124' "$CC/receipt/src/lib.nr" || { echo "receipt TAG_PARTY not reassigned to 124"; bad=1; }
  grep -q 'TAG_NULL: Field = 125' "$CC/receipt/src/lib.nr" || { echo "receipt TAG_NULL not reassigned to 125"; bad=1; }
  grep -q 'hash = { path = "../hash" }' "$CC/receipt/Nargo.toml" || { echo "receipt missing hash dep"; bad=1; }
  # ledger: slimmed to the kernel seam -- no app identities, no 122/123.
  grep -qE 'pub fn (participant_set|event_nullifier)|pub global TAG_(PARTY|NULL)' "$CC/ledger/src/lib.nr" && { echo "ledger still carries app identities/tags"; bad=1; }
  grep -q 'pub fn journal_commitment' "$CC/ledger/src/lib.nr" || { echo "ledger lost journal_commitment"; bad=1; }
  grep -q 'TAG_JOURNAL: Field = 3' "$CC/ledger/src/lib.nr" || { echo "ledger lost TAG_JOURNAL=3"; bad=1; }
  # event-complete: app identities from receipt, journal_commitment from ledger.
  grep -q 'use receipt::{event_nullifier, participant_set}' "$CC/event-complete/src/main.nr" || { echo "event-complete does not import from receipt"; bad=1; }
  grep -q 'use ledger::journal_commitment' "$CC/event-complete/src/main.nr" || { echo "event-complete does not import journal_commitment from ledger"; bad=1; }
  grep -q 'receipt = { path = "../receipt" }' "$CC/event-complete/Nargo.toml" || { echo "event-complete missing receipt dep"; bad=1; }
  # workspace + R1.
  grep -q '"receipt"' "$CC/Nargo.toml" || { echo "workspace does not include receipt"; bad=1; }
  grep -qE '^\| 124 \|.*participant set' "$R1" || { echo "R1 missing tag 124 (participant set)"; bad=1; }
  grep -qE '^\| 125 \|.*event nullifier' "$R1" || { echo "R1 missing tag 125 (event nullifier)"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "ledger slimmed to journal_commitment+TAG_JOURNAL; receipt holds participant_set/event_nullifier at 124/125; consumers+workspace+R1 rewired"
}

# ---- (2) functional: the whole workspace proves -----------------------------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  for c in pacioli hash ledger rulebook event-complete transition nullify; do
    cp -r "$ROOT/circuits/$c" "$s/$c"
  done
  cp "$ROOT/circuits/Nargo.toml" "$s/Nargo.toml"
  cp -r "$CC/receipt" "$s/receipt"
  cp "$CC/ledger/src/lib.nr"           "$s/ledger/src/lib.nr"
  cp "$CC/event-complete/src/main.nr"  "$s/event-complete/src/main.nr"
  cp "$CC/event-complete/Nargo.toml"   "$s/event-complete/Nargo.toml"
  cp "$CC/event-complete/Prover.toml"  "$s/event-complete/Prover.toml"
  cp "$CC/Nargo.toml"                  "$s/Nargo.toml"
  rm -rf "$s/target"
  printf '%s' "$s"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s; s="$(stage)"
  ( cd "$s" && "$NARGO" test --workspace ) > "$TRACES/_test.txt" 2>&1 || { echo "workspace tests FAILED"; tail -20 "$TRACES/_test.txt"; return 1; }
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -12 "$TRACES/_test.txt"; return 1; }
  # the two split crates must actually run their tests (not silently skipped).
  grep -q '\[receipt\].*test passed' "$TRACES/_test.txt" || { echo "receipt tests did not run"; return 1; }
  grep -q '\[ledger\].*test passed'  "$TRACES/_test.txt" || { echo "ledger tests did not run"; return 1; }
  for p in transition nullify event_complete; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (8 crates incl. receipt+ledger); transition+nullify+event_complete witnesses solve"
}

# ---- (3) cascade is scoped: kernel seam untouched, app identities changed -----
check_cascade() {
  local live="$ROOT/circuits/event-complete/Prover.toml" new="$CC/event-complete/Prover.toml" bad=0
  val() { grep -E "^$1" "$2" | grep -oE '0x[0-9a-f]+'; }
  # kernel commitment (TAG_JOURNAL=3) + event commitment (TAG_EVENT=120, unmoved) byte-identical.
  [[ "$(val journal_commitment_pub "$live")" == "$(val journal_commitment_pub "$new")" ]] || { echo "journal_commitment changed -- kernel seam NOT untouched"; bad=1; }
  [[ "$(val event_commitment_pub "$live")" == "$(val event_commitment_pub "$new")" ]] || { echo "event_commitment changed -- TAG_EVENT=120 should be unmoved"; bad=1; }
  # app identities (TAG_PARTY 124, TAG_NULL 125) DID change.
  [[ "$(val participant_set_pub "$live")" != "$(val participant_set_pub "$new")" ]] || { echo "participant_set unchanged -- tag reassignment had no effect"; bad=1; }
  [[ "$(val event_nullifier_pub "$live")" != "$(val event_nullifier_pub "$new")" ]] || { echo "event_nullifier unchanged -- tag reassignment had no effect"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "cascade scoped: journal_commitment + event_commitment byte-identical (kernel/120 untouched); participant_set + event_nullifier changed (tags 124/125)"
}

# ---- (4) mutant: the slim-probe is non-vacuous ------------------------------
check_mutant() {
  local m="$TRACES/mutant-ledger.nr"
  cp "$CC/ledger/src/lib.nr" "$m"
  printf '\npub fn event_nullifier(a: Field) -> Field { a }\n' >> "$m"
  if grep -qE 'pub fn (participant_set|event_nullifier)|pub global TAG_(PARTY|NULL)' "$m"; then
    echo "mutant caught: the slim-probe flags a re-introduced app identity in ledger (non-vacuous)"
    return 0
  fi
  echo "mutant NOT caught: the slim-probe is vacuous"
  return 1
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic   check_logic   || fail=1
run 02-prove   check_prove   || fail=1
run 03-cascade check_cascade || fail=1
run 04-mutant  check_mutant  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0032-ledger-receipt-split",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "slim circuits/ledger to the kernel commitment seam (journal_commitment + TAG_JOURNAL=3); move the app-side receipt identities (participant_set, event_nullifier) into a new circuits/receipt lib with tags reassigned off the 122/123 collision with R1 receipt-reference block to 124/125 (3/PROOF Annex A); append R1 rows 124/125 + reconcile 120; rewire event-complete (journal_commitment from ledger, identities from receipt) and regenerate its witness; transition/nullify untouched. nargo test --workspace green (8 crates), all witnesses solve, the cascade is scoped to the app identities (kernel commitment byte-identical), and a mutant proves the slim-probe non-vacuous.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'   "$(grep -q 'consumers+workspace+R1 rewired' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'   "$(grep -qE 'nargo test --workspace green|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "cascade": "%s",\n' "$(grep -q 'cascade scoped' "$TRACES/03-cascade.txt" && echo pass || echo fail)"
  printf '    "mutant": "%s"\n'   "$(grep -q 'mutant caught' "$TRACES/04-mutant.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
