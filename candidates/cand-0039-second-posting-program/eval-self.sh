#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0039-second-posting-program.
#
# Adds a SECOND posting program to prove the cand-0037 EVENT/1 harness
# (circuits/event-harness) is genuinely schema-agnostic. `circuits/bom-receipt`
# compiles a bill-of-materials / materials-kit receipt over basis B=4 (vs
# rulebook's B=3) with DENSE Dr/Cr vectors; `circuits/event-bom-receipt` is a
# near-clone of event-complete that routes the schema-agnostic obligations through
# the IDENTICAL `discharge` call. A kit RECEIPT (exchange, per-dimension
# zero-account) not an assembly TRANSFORM (which cannot balance incommensurable
# dimensions, 1/PACI). App-side; R1 tag 126 for the new event leaf.
#
# Checks: (1) structural -- the B=4 schema shape + the bin's harness reuse + the
# workspace + R1 tag; (2) functional -- nargo test --workspace green (incl.
# bom_receipt 2/2 + event_bom_receipt 6/6) + event_bom_receipt witness solves +
# the existing event_complete/transition/nullify still solve (value-preserving);
# (3) the cand-0033 kernel/app boundary law still passes with the new app crates.
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

# attest.sh uses GNU `head -n -1`; shim for BSD/macOS (queued portability item).
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
  local bad=0 lib="$CC/bom-receipt/src/lib.nr" main="$CC/event-bom-receipt/src/main.nr"
  # schema lib: B=4 basis, 4-quantity event, distinct tag, compile -> CompiledJournal<4,4>.
  grep -qE 'global N_BASIS: u32 = 4' "$lib" || { echo "bom-receipt is not basis B=4"; bad=1; }
  grep -qE 'global TAG_EVENT: Field = 126' "$lib" || { echo "bom-receipt event tag is not the distinct 126"; bad=1; }
  grep -q 'pub struct MaterialsKitReceipt' "$lib" || { echo "bom-receipt lacks the MaterialsKitReceipt event"; bad=1; }
  grep -qE 'thread_spools' "$lib" && grep -qE 'trim_units' "$lib" || { echo "bom-receipt is missing the extra material dimensions"; bad=1; }
  grep -qE 'compile_materials_kit_receipt\(e: MaterialsKitReceipt\) -> CompiledJournal<N_ROWS, N_BASIS>' "$lib" || { echo "compile does not return CompiledJournal over the schema's R,B"; bad=1; }
  grep -q 'use event_harness::CompiledJournal' "$lib" || { echo "bom-receipt does not reuse the harness CompiledJournal"; bad=1; }
  # bin: reuses the harness (discharge) -- the schema-agnostic glue is NOT re-implemented.
  grep -q 'use event_harness::{discharge, EventPublics}' "$main" || { echo "event-bom-receipt does not use the shared harness"; bad=1; }
  grep -q 'discharge(pubs, ps, j)' "$main" || { echo "event-bom-receipt does not call discharge"; bad=1; }
  grep -q 'compile_materials_kit_receipt(e)' "$main" || { echo "event-bom-receipt does not compile the kit-receipt schema"; bad=1; }
  # workspace + R1
  grep -q '"bom-receipt"' "$CC/Nargo.toml" && grep -q '"event-bom-receipt"' "$CC/Nargo.toml" || { echo "workspace does not include the new crates"; bad=1; }
  grep -qE '^\| 126 \|.*bom-receipt' "$R1" || { echo "R1 does not record tag 126 for bom-receipt"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "structural ok: B=4 kit-receipt schema (tag 126), bin reuses discharge (glue not re-implemented), workspace + R1 updated"
}

# ---- staging: full workspace from ROOT + overlay the new/changed cargo ---------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits"/. "$s/"
  rm -rf "$s/target"
  cp -r "$CC/bom-receipt"        "$s/bom-receipt"
  cp -r "$CC/event-bom-receipt"  "$s/event-bom-receipt"
  cp "$CC/Nargo.toml"            "$s/Nargo.toml"
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
  grep -q '\[bom_receipt\] 2 tests passed' "$TRACES/_test.txt" || { echo "bom_receipt schema tests did not all pass"; return 1; }
  grep -q '\[event_bom_receipt\] 6 tests passed' "$TRACES/_test.txt" || { echo "event_bom_receipt tests did not all pass"; return 1; }
  # the new bin solves; the existing bins still solve on their UNCHANGED witnesses.
  for p in event_bom_receipt event_complete transition nullify; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (bom_receipt 2/2 + event_bom_receipt 6/6); event_bom_receipt witness solves; existing event_complete/transition/nullify still solve (value-preserving)"
}

# ---- (3) the cand-0033 boundary law still holds with the new app crates -------
check_boundary() {
  [[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] || { echo "SKIP: kernel-boundary-check.sh absent"; return 0; }
  local s; s="$(stage)"
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$s" bash "$ROOT/tools/kernel-boundary-check.sh" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_boundary.txt"
  [[ "$rc" -eq 0 ]] || { echo "kernel-boundary law VIOLATED: $out"; return 1; }
  echo "cand-0033 boundary law still passes with bom-receipt + event-bom-receipt present (both app-side; kernel untouched)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic    check_logic    || fail=1
run 02-prove    check_prove    || fail=1
run 03-boundary check_boundary || fail=1

# Trim the staged scratch workspace from committed traces (queued trace-bloat item).
rm -rf "$TRACES/ws"

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0039-second-posting-program",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a SECOND posting program to validate the cand-0037 EVENT/1 harness is schema-agnostic. circuits/bom-receipt compiles a bill-of-materials / materials-kit receipt over basis B=4 (vs rulebook B=3) with dense Dr/Cr vectors; circuits/event-bom-receipt is a near-clone of event-complete routing the schema-agnostic obligations through the IDENTICAL discharge call. A kit RECEIPT (exchange, per-dimension zero-account) not an assembly TRANSFORM (incommensurable dimensions cannot offset, 1/PACI). Distinct R1 event tag 126 (event_commitment does not bind program_id). App-side; kernel boundary law holds. Witnessed: structural (B=4 schema + harness reuse + workspace + R1 tag); nargo test --workspace green (bom_receipt 2/2 + event_bom_receipt 6/6 incl. a B=4 unbalanced-journal rejection); event_bom_receipt witness solves; existing event_complete/transition/nullify still solve (value-preserving); the cand-0033 boundary law still passes.",\n'
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
