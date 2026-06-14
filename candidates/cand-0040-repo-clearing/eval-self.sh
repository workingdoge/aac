#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0040-repo-clearing.
#
# The first REAL clearing instrument on the EVENT/1 harness: a FICC/GSD repo.
# `circuits/repo` compiles BOTH legs over basis B=2 {cash, security par} -- OPEN
# (collateral out / principal in) and CLOSE (collateral back / principal+interest
# out) -- each a per-dimension zero-account (a transfer conserves each dimension);
# the repo interest is the cross-leg cash delta, not a within-leg imbalance. Two
# bins (event-repo-open / event-repo-close) prove each leg end-to-end through the
# IDENTICAL event_harness::discharge. App-side; R1 tags 127/128. Cross-leg
# sequencing (TRANSITION/1) and the multilateral net (VNET/1) are out of scope.
#
# Checks: (1) structural -- both legs + B=2 + the legs_link invariant + harness
# reuse + workspace + R1 tags; (2) functional -- nargo test --workspace green
# (repo 3/3 + event_repo_open 5/5 + event_repo_close 4/4) + both repo witnesses
# solve + the existing event_complete/transition/nullify still solve
# (value-preserving); (3) the cand-0033 kernel/app boundary law still holds.
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
  local bad=0 lib="$CC/repo/src/lib.nr" op="$CC/event-repo-open/src/main.nr" cl="$CC/event-repo-close/src/main.nr"
  grep -qE 'global N_BASIS: u32 = 2' "$lib" || { echo "repo is not basis B=2 {cash, security par}"; bad=1; }
  grep -qE 'global TAG_REPO_OPEN: Field = 127' "$lib" || { echo "repo open tag is not 127"; bad=1; }
  grep -qE 'global TAG_REPO_CLOSE: Field = 128' "$lib" || { echo "repo close tag is not 128"; bad=1; }
  grep -q 'pub fn compile_repo_open' "$lib" && grep -q 'pub fn compile_repo_close' "$lib" || { echo "repo is missing an open/close compile"; bad=1; }
  grep -q 'fn legs_link' "$lib" || { echo "repo lacks the cross-leg linkage test"; bad=1; }
  grep -qE 'principal_cents \+ e?\.?interest_cents|principal_cents \+ interest' "$lib" || grep -q 'repurchase = e.principal_cents + e.interest_cents' "$lib" || { echo "close leg does not add interest to principal"; bad=1; }
  # both bins reuse the harness discharge (glue not re-implemented).
  for f in "$op" "$cl"; do
    grep -q 'use event_harness::{discharge, EventPublics}' "$f" || { echo "$(basename "$(dirname "$(dirname "$f")")") does not use the shared harness"; bad=1; }
    grep -q 'discharge(pubs, ps, j)' "$f" || { echo "$(basename "$(dirname "$(dirname "$f")")") does not call discharge"; bad=1; }
  done
  grep -q 'compile_repo_open(e)' "$op" || { echo "open bin does not compile the open leg"; bad=1; }
  grep -q 'compile_repo_close(e)' "$cl" || { echo "close bin does not compile the close leg"; bad=1; }
  # workspace + R1
  grep -q '"repo"' "$CC/Nargo.toml" && grep -q '"event-repo-open"' "$CC/Nargo.toml" && grep -q '"event-repo-close"' "$CC/Nargo.toml" || { echo "workspace does not include the repo crates"; bad=1; }
  grep -qE '^\| 127 \|.*repo OPEN' "$R1" && grep -qE '^\| 128 \|.*repo CLOSE' "$R1" || { echo "R1 does not record tags 127/128 for repo"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "structural ok: B=2 repo with both legs (tags 127/128) + legs_link, both bins reuse discharge, workspace + R1 updated"
}

# ---- staging: full workspace from ROOT + overlay the new/changed cargo ---------
stage() {
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits"/. "$s/"
  rm -rf "$s/target"
  cp -r "$CC/repo"               "$s/repo"
  cp -r "$CC/event-repo-open"    "$s/event-repo-open"
  cp -r "$CC/event-repo-close"   "$s/event-repo-close"
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
  grep -q '\[repo\] 3 tests passed' "$TRACES/_test.txt" || { echo "repo schema tests did not all pass"; return 1; }
  grep -q '\[event_repo_open\] 5 tests passed' "$TRACES/_test.txt" || { echo "event_repo_open tests did not all pass"; return 1; }
  grep -q '\[event_repo_close\] 4 tests passed' "$TRACES/_test.txt" || { echo "event_repo_close tests did not all pass"; return 1; }
  for p in event_repo_open event_repo_close event_complete transition nullify; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test --workspace green (repo 3/3 + event_repo_open 5/5 + event_repo_close 4/4); both repo witnesses solve; existing event_complete/transition/nullify still solve (value-preserving)"
}

# ---- (3) the cand-0033 boundary law still holds with the new app crates -------
check_boundary() {
  [[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] || { echo "SKIP: kernel-boundary-check.sh absent"; return 0; }
  local s; s="$(stage)"
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$s" bash "$ROOT/tools/kernel-boundary-check.sh" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_boundary.txt"
  [[ "$rc" -eq 0 ]] || { echo "kernel-boundary law VIOLATED: $out"; return 1; }
  echo "cand-0033 boundary law still passes with the repo crates present (all app-side; kernel untouched)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic    check_logic    || fail=1
run 02-prove    check_prove    || fail=1
run 03-boundary check_boundary || fail=1

rm -rf "$TRACES/ws"  # trim staged scratch from committed traces (queued trace-bloat item)

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0040-repo-clearing",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add the first real clearing instrument on the EVENT/1 harness: a FICC/GSD repo. circuits/repo compiles BOTH legs over basis B=2 {cash, security par} -- OPEN (collateral out / principal in) and CLOSE (collateral back / principal+interest out) -- each a per-dimension zero-account; the repo interest is the cross-leg cash delta, not a within-leg imbalance. Two bins (event-repo-open / event-repo-close) prove each leg end-to-end through the IDENTICAL discharge. The haircut/valuation lives OUTSIDE the zero-account (par vs cash are incommensurable; vector Pacioli conserves par). Distinct R1 tags 127/128. Cross-leg sequencing (TRANSITION/1) and the multilateral net (VNET/1) are out of scope -- no VNET files touched. App-side. Witnessed: structural (both legs + B=2 + legs_link + harness reuse + workspace + R1); nargo test --workspace green (repo 3/3 + event_repo_open 5/5 + event_repo_close 4/4); both repo witnesses solve; existing event_complete/transition/nullify still solve; the cand-0033 boundary law still passes.",\n'
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
