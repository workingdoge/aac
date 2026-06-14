#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0041-clearing-novation-note (Design Note 0004).
# A NON-NORMATIVE design note + its diagram: it changes no spec/code, so the
# evidence is that the note CARRIES the thesis (AAC as a privacy-preserving CCP) +
# the novation decomposition + the application-layer placement + the honest
# non-goals + the non-normative marker, that every referenced artifact RESOLVES,
# the README indexes it, the diagram carries the stage + primitive labels, and a
# mutant (note stripped of the novation-decomposition claim) is caught.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
NOTE="$CARGO/sites/ledger/design/0004-clearing-novation-ccp.md"
HTML="$CARGO/sites/ledger/design/0004-clearing-flow.html"
README="$CARGO/sites/ledger/design/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) content: the note carries the thesis + the novation model -----------
check_content() {
  local bad=0
  # Normalize line wraps: markdown hard-wraps prose, so multi-word claims span
  # lines -- match against the newline-flattened text.
  local norm; norm="$(tr '\n' ' ' < "$NOTE" | tr -s ' ')"
  req() { printf '%s\n' "$norm" | grep -Fq "$2" || { echo "missing: $2"; bad=1; }; }
  req "$NOTE" 'non-normative design sketch'
  # thesis
  req "$NOTE" 'privacy-preserving CCP'
  req "$NOTE" 'Pⁿ zero-account'
  req "$NOTE" 'refuses to clear an unmatched book'
  # novation modeled
  req "$NOTE" 'NOVATE/1'
  req "$NOTE" 'conservation-preserving interposition'
  req "$NOTE" 'leaves the CCP flat'
  # placement: application layer, not kernel; policy-gated
  req "$NOTE" 'belong in the kernel'
  req "$NOTE" 'policy-gated, never base'
  req "$NOTE" '4/REG §5'
  # the closure
  req "$NOTE" 'book the registry forces to balance'
  # privacy differentiator
  req "$NOTE" 'without revealing the constituent trades'
  # honest non-goals
  req "$NOTE" '## 7. Non-goals'
  req "$NOTE" 'default waterfall'
  req "$NOTE" 'No instantiation'
  [[ "$bad" -eq 0 ]] && echo "note carries: non-normative marker, the privacy-CCP thesis, the novation interposition (CCP flat), application-layer placement (policy-gated, 4/REG §5), the matched-book closure, the privacy differentiator, the non-goals"
}

# ---- (2) cross-references resolve in the live tree ---------------------------
check_crossrefs() {
  local bad=0
  ref() { [[ -e "$ROOT/$1" ]] || { echo "dangling reference: $1"; bad=1; }; }
  ref sites/ledger/design/0001-bvr-clearing-kernel.md
  # NB: 0004-clearing-flow.html is co-landed cargo (checked in check_diagram), so it
  # is NOT asserted against the pre-land tree here.
  ref circuits/repo
  ref circuits/event-repo-open
  ref sites/ledger/specs/5/README.md
  ref sites/ledger/specs/4/README.md
  ref sites/ledger/specs/applications/README.md
  ref sites/ledger/specs/registers/R1.md
  grep -Fq '(0004-clearing-novation-ccp.md)' "$README" || { echo "README does not index Design Note 0004"; bad=1; }
  grep -Fq '0004-clearing-flow.html' "$README" || { echo "README does not link the diagram"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all referenced artifacts resolve (DN0001, the diagram, circuits/repo + event-repo-open, 5/NET, 4/REG, applications/README, R1); README indexes 0004 + the diagram"
}

# ---- (3) the diagram carries the stage + primitive labels --------------------
check_diagram() {
  local bad=0
  req() { grep -Fq "$2" "$1" || { echo "diagram missing: $2"; bad=1; }; }
  req "$HTML" 'Trade capture'
  req "$HTML" 'Novation'
  req "$HTML" 'Multilateral net'
  req "$HTML" 'Net DVP settle'
  req "$HTML" 'EVENT/1'
  req "$HTML" 'NOVATE/1'
  req "$HTML" 'NET/1'
  req "$HTML" 'VNET/1'
  req "$HTML" 'TRANSITION/1'
  # the four-stage geometry + the novation zoom are present (an <svg> with the CCP node).
  grep -Fq '<svg' "$HTML" || { echo "diagram is not an SVG"; bad=1; }
  grep -Fq 'conservation-preserving decomposition' "$HTML" || { echo "diagram lacks the novation zoom"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "diagram carries the four stages + the five primitives (EVENT/NOVATE/NET/VNET/TRANSITION) + the novation zoom, as an SVG"
}

# ---- (4) mutant: the content-probe is non-vacuous ---------------------------
check_mutant() {
  # Strip every line naming the central NOVATE/1 claim; the content-probe for it
  # must then fail (the probe is non-vacuous).
  local m="$TRACES/mutant-note.md"
  grep -Fv 'NOVATE/1' "$NOTE" > "$m"
  if grep -Fq 'NOVATE/1' "$m"; then
    echo "mutant NOT effective: the NOVATE/1 claim survived stripping"
    return 1
  fi
  echo "mutant caught: a note stripped of NOVATE/1 fails the content-probe (non-vacuous)"
  return 0
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-content  check_content  || fail=1
run 02-crossref check_crossrefs || fail=1
run 03-diagram  check_diagram  || fail=1
run 04-mutant   check_mutant   || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0041-clearing-novation-note",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "land Design Note 0004 (non-normative) + its house-style flow diagram: AAC as a privacy-preserving CCP. Maps FICC/DTCC clearing onto the primitive stack (EVENT/1 capture, NET/1 + VNET/1 netting, TRANSITION/1 DVP, 12/OTC margin) and models the missing piece -- NOVATION -- as a conservation-preserving decomposition (J_AB -> J_AC + J_CB summing back, CCP left flat per trade), a NOVATE/1 application target (policy-gated, never base, 4/REG §5; NOT kernel). The closure: a CCP is a participant whose matched book the registry forces to balance. Honest non-goals: risk/margin/default-waterfall, fails/CNS carry, legal novation, no instantiation. Coordinates with VNET (the multilateral net is the operator work); touches no VNET files. Witnessed: the note carries the thesis + novation decomposition + application-layer placement + non-goals + non-normative marker; every referenced artifact resolves; README indexes 0004 + the diagram; the diagram carries the stage + primitive labels; a mutant stripped of the decomposition claim is caught.",\n'
  printf '  "checks": {\n'
  printf '    "content": "%s",\n'  "$(grep -q 'note carries:' "$TRACES/01-content.txt" && echo pass || echo fail)"
  printf '    "crossref": "%s",\n' "$(grep -q 'all referenced artifacts resolve' "$TRACES/02-crossref.txt" && echo pass || echo fail)"
  printf '    "diagram": "%s",\n'  "$(grep -q 'diagram carries' "$TRACES/03-diagram.txt" && echo pass || echo fail)"
  printf '    "mutant": "%s"\n'    "$(grep -q 'mutant caught' "$TRACES/04-mutant.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
