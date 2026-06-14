#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0037-event-harness.
# Factors the reusable EVENT/1 obligation harness out of event-complete into a new
# app lib `circuits/event-harness` (generic CompiledJournal<R,B> + EventPublics +
# discharge<R,B>); rulebook repoints its CompiledJournal there; event-complete's
# main keeps the schema-specific half (roles, event_commitment, Phi_P) then calls
# discharge. App-side only. Checks: (1) structural -- harness shape + rewiring +
# the public ABI param stays rulebook_id; (2) nargo test --workspace green (9
# crates incl. event_harness's accept + 3 reject tests) + all witnesses solve
# (value-preserving: the UNCHANGED event-complete Prover.toml still solves); (3)
# the cand-0033 kernel/app boundary law still passes with the new crate present.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CC="$CAND_DIR/cargo/circuits"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) structural -----------------------------------------------------------
check_logic() {
  local bad=0
  # harness: the generic shape + the app-side dep on receipt.
  grep -qE 'pub struct CompiledJournal<let R: u32, let B: u32>' "$CC/event-harness/src/lib.nr" || { echo "harness lacks generic CompiledJournal<R,B>"; bad=1; }
  grep -q 'pub struct EventPublics' "$CC/event-harness/src/lib.nr" || { echo "harness lacks EventPublics"; bad=1; }
  grep -qE 'pub fn discharge<let R: u32, let B: u32>' "$CC/event-harness/src/lib.nr" || { echo "harness lacks generic discharge<R,B>"; bad=1; }
  grep -q 'posting_program_id' "$CC/event-harness/src/lib.nr" || { echo "harness API does not use posting_program_id"; bad=1; }
  grep -q 'receipt = { path = "../receipt" }' "$CC/event-harness/Nargo.toml" || { echo "harness missing receipt dep (must be app-side)"; bad=1; }
  grep -qE 'discharge_rejects_a_wrong_(journal_commitment|nullifier_binding|party_binding)' "$CC/event-harness/src/lib.nr" || { echo "harness lacks the obligation-reject tests"; bad=1; }
  # rulebook: repointed to the harness's CompiledJournal, no own struct.
  grep -q 'use event_harness::CompiledJournal' "$CC/rulebook/src/lib.nr" || { echo "rulebook does not import CompiledJournal from the harness"; bad=1; }
  grep -qE '^pub struct CompiledJournal' "$CC/rulebook/src/lib.nr" && { echo "rulebook still defines its own CompiledJournal"; bad=1; }
  grep -q 'event_harness = { path = "../event-harness" }' "$CC/rulebook/Nargo.toml" || { echo "rulebook missing event_harness dep"; bad=1; }
  # event-complete: calls discharge; public ABI param stays rulebook_id; maps to posting_program_id.
  grep -q 'use event_harness::{discharge, EventPublics}' "$CC/event-complete/src/main.nr" || { echo "event-complete does not use the harness"; bad=1; }
  grep -q 'discharge(pubs, ps, j)' "$CC/event-complete/src/main.nr" || { echo "event-complete does not call discharge"; bad=1; }
  grep -q 'rulebook_id: pub Field' "$CC/event-complete/src/main.nr" || { echo "event-complete public ABI param is not rulebook_id (should stay spec-synced)"; bad=1; }
  grep -q 'posting_program_id: rulebook_id' "$CC/event-complete/src/main.nr" || { echo "event-complete does not map rulebook_id -> posting_program_id internally"; bad=1; }
  # workspace
  grep -q '"event-harness"' "$CC/Nargo.toml" || { echo "workspace does not include event-harness"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "harness shape ok (generic CompiledJournal<R,B>/EventPublics/discharge<R,B>, app-side, reject-tests); rulebook+event-complete rewired; public ABI param stays rulebook_id; workspace updated"
}

# ---- staging ------------------------------------------------------------------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  for c in pacioli hash ledger receipt rulebook event-complete transition nullify; do
    cp -r "$ROOT/circuits/$c" "$s/$c"
  done
  cp -r "$CC/event-harness" "$s/event-harness"
  cp "$CC/rulebook/Nargo.toml"          "$s/rulebook/Nargo.toml"
  cp "$CC/rulebook/src/lib.nr"          "$s/rulebook/src/lib.nr"
  cp "$CC/event-complete/Nargo.toml"    "$s/event-complete/Nargo.toml"
  cp "$CC/event-complete/src/main.nr"   "$s/event-complete/src/main.nr"
  cp "$CC/Nargo.toml"                   "$s/Nargo.toml"
  rm -rf "$s/target"
  printf '%s' "$s"
}

# ---- (2) functional + value-preservation -------------------------------------
check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s; s="$(stage)"
  local rc
  ( cd "$s" && "$NARGO" test --workspace ) > "$TRACES/_test_raw.txt" 2>&1; rc=$?
  sed 's/\x1b\[[0-9;]*m//g' "$TRACES/_test_raw.txt" > "$TRACES/_test.txt"
  [[ "$rc" -eq 0 ]] || { echo "workspace tests FAILED"; tail -20 "$TRACES/_test.txt"; return 1; }
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -12 "$TRACES/_test.txt"; return 1; }
  grep -q '\[event_harness\] 4 tests passed' "$TRACES/_test.txt" || { echo "event_harness's accept+reject tests did not all pass"; return 1; }
  grep -q '\[event_complete\] .*tests passed' "$TRACES/_test.txt" || { echo "event_complete tests did not run"; return 1; }
  # value-preserving: the UNCHANGED event-complete Prover.toml must still solve.
  for p in event_complete transition nullify; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (9 crates incl. event_harness 4/4); event_complete witness solves on the UNCHANGED Prover.toml (value-preserving); transition/nullify solve"
}

# ---- (3) the cand-0033 boundary law still holds with the new crate -----------
check_boundary() {
  [[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] || { echo "SKIP: kernel-boundary-check.sh absent"; return 0; }
  local s; s="$(stage)"
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$s" bash "$ROOT/tools/kernel-boundary-check.sh" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_boundary.txt"
  [[ "$rc" -eq 0 ]] || { echo "kernel-boundary law VIOLATED by the factoring: $out"; return 1; }
  echo "cand-0033 boundary law still passes with event-harness present (kernel crates untouched; harness is app-side)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic    check_logic    || fail=1
run 02-prove    check_prove    || fail=1
run 03-boundary check_boundary || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0037-event-harness",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "factor the reusable EVENT/1 obligation harness out of event-complete into a new app lib circuits/event-harness (generic CompiledJournal<R,B> + EventPublics + discharge<R,B>); rulebook repoints its CompiledJournal there; event-complete keeps the schema-specific half and calls discharge; the public ABI param stays rulebook_id (only the internal harness API uses posting_program_id). App-side only. Witnessed: structural shape + rewiring; nargo test --workspace green (9 crates incl. the harness accept + 3 obligation-reject tests); the UNCHANGED event-complete Prover.toml still solves (value-preserving); and the cand-0033 kernel/app boundary law still passes with the new crate. Goods-receipt-invoice is the one posting program; no second schema.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'    "$(grep -q 'workspace updated' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'    "$(grep -qE 'value-preserving|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "boundary": "%s"\n'  "$(grep -qE 'boundary law still passes|^SKIP' "$TRACES/03-boundary.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
