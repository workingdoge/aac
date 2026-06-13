#!/usr/bin/env bash
# eval-self.sh — evidence for cand-0008-bvr-clearing-kernel.
# A design note's evidence is structural: it declares itself non-normative,
# states the load-bearing architecture decisions, and every spec/code artifact
# it leans on actually exists in the tree (no dangling cross-references).
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
NOTE="$CAND_DIR/cargo/sites/ledger/design/0001-bvr-clearing-kernel.md"
IDX="$CAND_DIR/cargo/sites/ledger/design/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  [[ -f "$NOTE" ]] || { echo "design note missing"; bad=1; }
  [[ -f "$IDX" ]]  || { echo "design/README index missing"; bad=1; }
  grep -qi 'non-normative' "$NOTE" && grep -qi 'non-normative' "$IDX" || { echo "not marked non-normative"; bad=1; }
  grep -qi 'NOT an RFC' "$NOTE" || { echo "note does not disclaim RFC status"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "note + index present, marked non-normative, disclaims RFC status"
}

check_doctrine() {
  # The load-bearing decisions must be stated.
  local bad=0
  # Phi_R is an APPLICATION target, NOT enshrined; TRANSITION/1 stays minimal.
  grep -q 'application target' "$NOTE" || { echo "missing application-target placement"; bad=1; }
  grep -qE 'MUST NOT.*TRANSITION/1|not.*enshrined' "$NOTE" || { echo "does not keep Phi_R out of the enshrined target"; bad=1; }
  # VNET/1 separated from 5/NET.
  grep -q 'VNET/1' "$NOTE" && grep -q '5/NET' "$NOTE" || { echo "VNET/1 vs 5/NET distinction missing"; bad=1; }
  grep -qi 'message identity' "$NOTE" && grep -qi 'per-dimension' "$NOTE" || { echo "the two-netting distinction is not characterized"; bad=1; }
  # Security boundary: completeness, not truth.
  grep -qi 'completeness, not truth' "$NOTE" || { echo "security boundary (completeness != truth) missing"; bad=1; }
  # The hash split (Poseidon2 in-circuit vs homomorphic Pedersen commitment).
  grep -qi 'Poseidon2' "$NOTE" && grep -qi 'Pedersen vector commitment' "$NOTE" || { echo "hash-primitive split missing"; bad=1; }
  # The canonical object + compiler.
  grep -q 'BalancedVectorReceipt' "$NOTE" && grep -qE 'Phi_R|Φ_R' "$NOTE" || { echo "BVR object / compiler missing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "doctrine stated: BVR object + Phi_R app-target + VNET/5NET split + security boundary + hash split"
}

check_crossrefs() {
  # Every artifact the note claims AAC already has must actually exist.
  local bad=0
  for p in \
    sites/ledger/statements/Core.lean \
    sites/ledger/specs/1/README.md \
    sites/ledger/specs/2/README.md \
    sites/ledger/specs/3/README.md \
    sites/ledger/specs/4/README.md \
    sites/ledger/specs/5/README.md \
    circuits/pacioli/src/lib.nr \
    circuits/transition/src/main.nr ; do
    [[ -e "$ROOT/$p" ]] || { echo "dangling cross-reference: $p"; bad=1; }
  done
  # The note's central claims must be checkable against those files:
  grep -q 'Basis → ℕ' "$ROOT/sites/ledger/statements/Core.lean" || { echo "Core.lean vector-amount claim unverified"; bad=1; }
  grep -qiE 'vectors .*\^B|ℕ\^B|N\^B' "$ROOT/sites/ledger/specs/1/README.md" || { echo "1/PACI vector-profile claim unverified"; bad=1; }
  grep -qi 'valuation' "$ROOT/sites/ledger/specs/1/README.md" || { echo "1/PACI valuation/no-numeraire claim unverified"; bad=1; }
  grep -q 'journal_balanced' "$ROOT/circuits/pacioli/src/lib.nr" || { echo "pacioli per-basis claim unverified"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all cross-references resolve; core claims verified against Core.lean / 1-PACI / pacioli"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present   check_present   || fail=1
run 02-doctrine  check_doctrine  || fail=1
run 03-crossrefs check_crossrefs || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0008-bvr-clearing-kernel",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "BVR / P^n clearing-kernel design note (non-normative) — states the BVR object, Phi_R-as-application-target doctrine, VNET/1-vs-5/NET split, the completeness-not-truth boundary, and the Poseidon2/Pedersen hash split; all cross-references resolve",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n'   "$(grep -q 'non-normative' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "doctrine": "%s",\n'  "$(grep -q 'doctrine stated' "$TRACES/02-doctrine.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s"\n'  "$(grep -q 'cross-references resolve' "$TRACES/03-crossrefs.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
