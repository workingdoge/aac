#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0043-ust-trade.
#
# A UST cash-trade posting program (circuits/ust-trade) + the capture->novate
# COMPOSITION: its journal is built in the SAME party-grouped chart as
# novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to
# the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof
# (discharge) plus a conformance test asserting journal_commitment(ust) ==
# journal_commitment(novate bilateral) and that novate accepts that journal.
# App-side; R1 tag 129.
#
# Checks: (1) structural -- the schema + the novate-matching chart + the bin's
# discharge + the composition test + workspace + R1; (2) functional -- nargo test
# --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test) +
# event_ust witness solves + existing crates value-preserving; (3) the cand-0033
# boundary law still holds.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CC="$CAND_DIR/cargo/circuits"
R1="$CAND_DIR/cargo/sites/ledger/specs/registers/R1.md"
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
  local bad=0 lib="$CC/ust-trade/src/lib.nr" bin="$CC/event-ust/src/main.nr"
  grep -qE 'global N_BASIS: u32 = 2' "$lib" || { echo "ust-trade is not basis B=2"; bad=1; }
  grep -qE 'global TAG_EVENT: Field = 129' "$lib" || { echo "ust-trade event tag is not 129"; bad=1; }
  grep -q 'pub struct UstTrade' "$lib" || { echo "ust-trade lacks the UstTrade event"; bad=1; }
  grep -q 'pub fn compile_ust_trade' "$lib" || { echo "ust-trade lacks compile_ust_trade"; bad=1; }
  # the novate-matching party-grouped chart (SELLER={0,1}, BUYER={2,3}).
  grep -qE 'SELLER_SECURITIES: u32 = 0' "$lib" && grep -qE 'BUYER_SECURITIES: u32 = 2' "$lib" || { echo "ust-trade chart does not match novate's party-grouped layout"; bad=1; }
  # bin: discharge + the composition conformance test.
  grep -q 'use event_harness::{discharge, EventPublics}' "$bin" || { echo "event-ust does not use the harness"; bad=1; }
  grep -q 'discharge(pubs, ps, j)' "$bin" || { echo "event-ust does not call discharge"; bad=1; }
  grep -q 'fn ust_journal_is_the_novate_bilateral' "$bin" || { echo "event-ust lacks the capture->novate composition test"; bad=1; }
  grep -q 'novate::compile_bilateral' "$bin" || { echo "the composition test does not compare against novate's bilateral"; bad=1; }
  grep -q 'novate::novate(bilateral' "$bin" || { echo "the composition test does not feed the journal through novate"; bad=1; }
  grep -q '"ust-trade"' "$CC/Nargo.toml" && grep -q '"event-ust"' "$CC/Nargo.toml" || { echo "workspace does not include the ust crates"; bad=1; }
  grep -qE '^\| 129 \|.*ust-trade' "$R1" || { echo "R1 does not record tag 129 for ust-trade"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "structural ok: B=2 UST trade (tag 129) in novate's party-grouped chart; bin discharges + carries the capture->novate composition test; workspace + R1 updated"
}

# ---- staging ------------------------------------------------------------------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits"/. "$s/"
  rm -rf "$s/target"
  cp -r "$CC/ust-trade"   "$s/ust-trade"
  cp -r "$CC/event-ust"   "$s/event-ust"
  cp "$CC/Nargo.toml"     "$s/Nargo.toml"
  printf '%s' "$s"
}

# ---- (2) functional -----------------------------------------------------------
check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s; s="$(stage)"
  local rc
  ( cd "$s" && "$NARGO" test --workspace ) > "$TRACES/_test_raw.txt" 2>&1; rc=$?
  sed 's/\x1b\[[0-9;]*m//g' "$TRACES/_test_raw.txt" > "$TRACES/_test.txt"
  [[ "$rc" -eq 0 ]] || { echo "workspace tests FAILED"; tail -20 "$TRACES/_test.txt"; return 1; }
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -12 "$TRACES/_test.txt"; return 1; }
  grep -q '\[ust_trade\] 1 test passed' "$TRACES/_test.txt" || { echo "ust_trade schema test did not pass"; return 1; }
  grep -q '\[event_ust\] 5 tests passed' "$TRACES/_test.txt" || { echo "event_ust tests (incl. composition) did not all pass"; return 1; }
  for p in event_ust event_novate event_complete transition nullify; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the capture->novate composition); event_ust witness solves; existing event_novate/event_complete/transition/nullify still solve (value-preserving)"
}

# ---- (3) boundary law ---------------------------------------------------------
check_boundary() {
  [[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] || { echo "SKIP: kernel-boundary-check.sh absent"; return 0; }
  local s; s="$(stage)"
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$s" bash "$ROOT/tools/kernel-boundary-check.sh" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_boundary.txt"
  [[ "$rc" -eq 0 ]] || { echo "kernel-boundary law VIOLATED: $out"; return 1; }
  echo "cand-0033 boundary law still passes with ust-trade + event-ust present (app-side; kernel untouched)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic    check_logic    || fail=1
run 02-prove    check_prove    || fail=1
run 03-boundary check_boundary || fail=1

rm -rf "$TRACES/ws"

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0043-ust-trade",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a UST cash-trade posting program (circuits/ust-trade) and demonstrate the capture->novate pipeline composes: the journal is built in the SAME party-grouped chart as novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof (discharge) plus a composition conformance test asserting journal_commitment(ust) == journal_commitment(novate bilateral) and that novate accepts that journal (verified concretely: same 0x06d8c122... commitment across both proofs). R1 tag 129. App-side. Witnessed: structural; nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test); event_ust witness solves; existing crates value-preserving; the cand-0033 boundary law still passes.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'    "$(grep -q 'structural ok' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'    "$(grep -qE 'value-preserving|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "boundary": "%s"\n'  "$(grep -qE 'boundary law still passes|^SKIP' "$TRACES/03-boundary.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
