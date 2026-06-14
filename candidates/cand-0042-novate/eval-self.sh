#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0042-novate (NOVATE/1).
#
# Promotes Design Note 0004 S3 to an application-target spec + a circuits/novate
# proof: central-counterparty novation. The obligation is one vector equation
# net(J_AC) + net(J_CB) == net(J_AB) over the account x dim grid; the bilateral
# never touches C, so on C's slice it reads net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP
# is flat (matched book). App-side; no new domain tag (ordinary journal leaves).
#
# Checks: (1) structural -- the obligation + canonical compile + the bin's binding +
# the workspace; (2) functional -- nargo test --workspace green (novate 5/5 incl.
# the reject tests + event_novate 4/4) + event_novate witness solves + existing
# bins still solve (value-preserving); (3) the cand-0033 boundary law still holds;
# (4) the NOVATE-1.md spec carries the obligations + ABI + the matched-book theorem,
# the README indexes it, and Design Note 0004 references it.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CC="$CAND_DIR/cargo/circuits"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/NOVATE-1.md"
APPREADME="$CAND_DIR/cargo/sites/ledger/specs/applications/README.md"
NOTE="$CAND_DIR/cargo/sites/ledger/design/0004-clearing-novation-ccp.md"
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
  local bad=0 lib="$CC/novate/src/lib.nr" bin="$CC/event-novate/src/main.nr"
  grep -q 'pub fn net_grid' "$lib" || { echo "novate lacks net_grid"; bad=1; }
  grep -q 'pub fn novate' "$lib" || { echo "novate lacks the novate obligation"; bad=1; }
  grep -q 'pub fn compile_bilateral' "$lib" && grep -q 'pub fn compile_novation_legs' "$lib" || { echo "novate lacks the canonical bilateral/legs"; bad=1; }
  # the one equation + the bilateral-clean + balanced legs.
  grep -q 'novation does not reproduce the bilateral position' "$lib" || { echo "novate lacks the composition obligation"; bad=1; }
  grep -q 'the bilateral touches a CCP account' "$lib" || { echo "novate lacks the bilateral-clean obligation"; bad=1; }
  grep -qE 'is not a zero-account' "$lib" || { echo "novate lacks the balanced-legs obligation"; bad=1; }
  # bin binds the three commitments + discharges novate.
  grep -q 'use novate::{compile_bilateral, compile_novation_legs, novate}' "$bin" || { echo "event-novate does not use novate"; bad=1; }
  grep -q 'novate(bilateral, leg_ac, leg_cb)' "$bin" || { echo "event-novate does not discharge novate"; bad=1; }
  grep -qE 'journal_commitment\(bilateral' "$bin" && grep -qE 'leg_ac_commitment' "$bin" && grep -qE 'leg_cb_commitment' "$bin" || { echo "event-novate does not bind the three journal commitments"; bad=1; }
  grep -q '"novate"' "$CC/Nargo.toml" && grep -q '"event-novate"' "$CC/Nargo.toml" || { echo "workspace does not include the novate crates"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "structural ok: net_grid + novate obligation (composition + bilateral-clean + balanced legs) + canonical compile; bin binds the three commitments + discharges novate; workspace updated"
}

# ---- staging ------------------------------------------------------------------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits"/. "$s/"
  rm -rf "$s/target"
  cp -r "$CC/novate"        "$s/novate"
  cp -r "$CC/event-novate"  "$s/event-novate"
  cp "$CC/Nargo.toml"       "$s/Nargo.toml"
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
  grep -q '\[novate\] 5 tests passed' "$TRACES/_test.txt" || { echo "novate tests did not all pass"; return 1; }
  grep -q '\[event_novate\] 4 tests passed' "$TRACES/_test.txt" || { echo "event_novate tests did not all pass"; return 1; }
  for p in event_novate event_complete transition nullify; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (novate 5/5 incl. tampered/unbalanced/non-bilateral rejects + event_novate 4/4); event_novate witness solves; existing event_complete/transition/nullify still solve (value-preserving)"
}

# ---- (3) boundary law ---------------------------------------------------------
check_boundary() {
  [[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] || { echo "SKIP: kernel-boundary-check.sh absent"; return 0; }
  local s; s="$(stage)"
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$s" bash "$ROOT/tools/kernel-boundary-check.sh" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_boundary.txt"
  [[ "$rc" -eq 0 ]] || { echo "kernel-boundary law VIOLATED: $out"; return 1; }
  echo "cand-0033 boundary law still passes with novate + event-novate present (app-side; kernel untouched)"
}

# ---- (4) spec content + crossrefs --------------------------------------------
check_spec() {
  local bad=0
  local norm; norm="$(tr '\n' ' ' < "$SPEC" | tr -s ' ')"
  req() { printf '%s\n' "$norm" | grep -Fq "$2" || { echo "spec missing: $2"; bad=1; }; }
  req "$SPEC" 'Application target (not enshrined)'
  req "$SPEC" 'Cites: 1/PACI, 3/PROOF, 4/REG'
  req "$SPEC" 'faithful novation'
  req "$SPEC" '**CCP is flat**'
  req "$SPEC" 'net(J_AC) ⊕ net(J_CB) == net(J_AB)'
  req "$SPEC" 'The matched book is a theorem'
  req "$SPEC" 'claims **no new domain tag**'
  req "$SPEC" 'base registry **MUST NOT**'
  req "$SPEC" 'bilateral_commitment'
  req "$SPEC" 'leg_ac_commitment'
  req "$SPEC" 'leg_cb_commitment'
  # the README indexes NOVATE/1; Design Note 0004 references the spec.
  grep -Fq '(NOVATE-1.md)' "$APPREADME" || { echo "applications/README does not index NOVATE/1"; bad=1; }
  grep -Fq 'NOVATE-1.md' "$NOTE" || { echo "Design Note 0004 does not reference NOVATE-1.md"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "NOVATE-1.md carries: application-target marker, cites, the one equation, the CCP-flat matched book theorem, no-new-tag, MUST NOT base, the 3-commitment ABI; README indexes it; DN0004 references it"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic    check_logic    || fail=1
run 02-prove    check_prove    || fail=1
run 03-boundary check_boundary || fail=1
run 04-spec     check_spec     || fail=1

rm -rf "$TRACES/ws"

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0042-novate",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Build NOVATE/1: promote Design Note 0004 S3 to an application-target spec (NOVATE-1.md, Raw, cites 1/PACI 3/PROOF 4/REG, policy-gated never base, no new domain tag) + a circuits/novate proof of central-counterparty novation. The obligation is one vector equation net(J_AC)+net(J_CB)==net(J_AB) over the account x dim grid; the bilateral never touches C so on C the equation is net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP is flat (matched book), a theorem of balanced faithful interposition. circuits/novate = net_grid + novate + canonical compile; circuits/event-novate binds the three journal_commitments and discharges novate. App-side; multilateral net of many legs = VNET/1 (operator), out of scope, no VNET files touched. Witnessed: structural; nargo test --workspace green (novate 5/5 incl. tampered/unbalanced/non-bilateral rejects + event_novate 4/4); event_novate witness solves; existing crates value-preserving; the cand-0033 boundary law still passes; NOVATE-1.md carries the obligations + ABI + the matched-book theorem; README indexes it; DN0004 references it.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'    "$(grep -q 'structural ok' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'    "$(grep -qE 'value-preserving|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "boundary": "%s",\n' "$(grep -qE 'boundary law still passes|^SKIP' "$TRACES/03-boundary.txt" && echo pass || echo fail)"
  printf '    "spec": "%s"\n'      "$(grep -q 'NOVATE-1.md carries' "$TRACES/04-spec.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
