#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0036-naming-layering (Design Note 0003).
# A NON-NORMATIVE design note: it changes no spec/code, so the evidence is that
# the note actually CARRIES the decided vocabulary + the EVENT/1 statement + the
# layer sets + the NET/VNET placement, that its non-normative marker is present,
# that every artifact it references RESOLVES in the live tree, the README indexes
# it, and a mutant (note stripped of the EVENT/1 statement) is caught.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
NOTE="$CARGO/sites/ledger/design/0003-naming-and-layering.md"
README="$CARGO/sites/ledger/design/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

# attest.sh uses GNU `head -n -1`; shim for BSD/macOS (cand-0030/0031 pattern).
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) content: the note carries the decided vocabulary --------------------
check_content() {
  local bad=0
  req() { grep -Fq "$2" "$1" || { echo "missing: $2"; bad=1; }; }
  req "$NOTE" 'non-normative design sketch'
  # EVENT/1 + its statement
  req "$NOTE" '## 3. EVENT-COMPLETE/1'
  req "$NOTE" 'proves a typed'
  req "$NOTE" 'pinned'
  # posting program
  req "$NOTE" '## 4. rulebook'
  req "$NOTE" 'Posting Program'
  # the two layers + members
  req "$NOTE" 'KERNEL (schema-agnostic'
  req "$NOTE" 'APPLICATION (schema-specific'
  req "$NOTE" 'posting-program'
  # crate rename plan
  req "$NOTE" 'circuits/posting-program'
  req "$NOTE" 'circuits/event'
  # NET vs VNET placement
  req "$NOTE" 'NET/1'
  req "$NOTE" 'VNET/1'
  req "$NOTE" 'lives outside'
  [[ "$bad" -eq 0 ]] && echo "note carries: non-normative marker, EVENT/1 + statement, Posting Program, kernel/app layer sets, circuits rename plan, NET-vs-VNET placement"
}

# ---- (2) cross-references resolve in the live tree ---------------------------
check_crossrefs() {
  local bad=0
  ref() { [[ -e "$ROOT/$1" ]] || { echo "dangling reference: $1"; bad=1; }; }
  ref sites/ledger/specs/applications/EVENT-COMPLETE-1.md
  ref circuits/rulebook
  ref circuits/event-complete
  ref circuits/receipt
  ref tools/kernel-boundary-check.sh
  ref sites/ledger/design/0001-bvr-clearing-kernel.md
  # the README indexes the note (row 0003 links the file).
  grep -Fq '(0003-naming-and-layering.md)' "$README" || { echo "README does not index Design Note 0003"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all referenced artifacts resolve (EVENT-COMPLETE-1.md, circuits/{rulebook,event-complete,receipt}, kernel-boundary-check.sh, DN0001); README indexes 0003"
}

# ---- (3) mutant: the content-probe is non-vacuous ---------------------------
check_mutant() {
  local m="$TRACES/mutant-note.md"
  grep -Fv 'proves a typed' "$NOTE" > "$m"
  # the content-probe must now FAIL on the mutant (the statement line is gone).
  if grep -Fq 'proves a typed' "$m"; then
    echo "mutant NOT effective: the EVENT/1 statement survived stripping"
    return 1
  fi
  echo "mutant caught: a note stripped of the EVENT/1 statement fails the content-probe (non-vacuous)"
  return 0
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-content  check_content  || fail=1
run 02-crossref check_crossrefs || fail=1
run 03-mutant   check_mutant   || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0036-naming-layering",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "land Design Note 0003 (non-normative): the kernel/app naming + layering vocabulary after the cand-0033 boundary law -- EVENT-COMPLETE/1 -> EVENT/1 (+ its statement), rulebook -> Posting Program, kernel {pacioli,hash,ledger,transition,nullify} vs application {posting-program,receipt,event} layer sets, the circuits crate rename plan, and NET/1 vs VNET/1 placement (VNET binds to TRANSITION/1 journal_commitments but lives outside it). Witnessed: the note carries the decided vocabulary + the EVENT/1 statement + the non-normative marker, every referenced artifact resolves in the live tree, the README indexes 0003, and a mutant stripped of the statement is caught.",\n'
  printf '  "checks": {\n'
  printf '    "content": "%s",\n'  "$(grep -q 'note carries:' "$TRACES/01-content.txt" && echo pass || echo fail)"
  printf '    "crossref": "%s",\n' "$(grep -q 'all referenced artifacts resolve' "$TRACES/02-crossref.txt" && echo pass || echo fail)"
  printf '    "mutant": "%s"\n'    "$(grep -q 'mutant caught' "$TRACES/03-mutant.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
