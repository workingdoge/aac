#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0034-vnet-pedersen.
# VNET/1 is a Raw application-target spec. Evidence is structural: the spec must
# carry the Pedersen vector commitment profile, transition-journal linkage, the
# zero-opening proof requirement, the VNET/5NET separation, and non-vacuous
# rejection checks.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs/applications"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

VNET="$CARGO/VNET-1.md"
APP_INDEX="$CARGO/README.md"
EVENT="$CARGO/EVENT-COMPLETE-1.md"

# tools/eval/attest.sh uses GNU `head -n -1`. On BSD/macOS, provide the exact
# behavior to the child bash process without modifying the verifier-set tool.
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

check_vnet_spec() {
  local f="$1" bad=0
  grep -q 'Application target (not enshrined)' "$f" || { echo "missing non-enshrined target marker"; bad=1; }
  grep -q '5/NET nets channel facts over Z\[X\]' "$f" || { echo "missing 5NET/VNET separation"; bad=1; }
  grep -q 'VNET/1 nets amount vectors over P\^n' "$f" || { echo "missing amount-vector statement"; bad=1; }
  grep -q 'hash_to_curve("aac/vnet/1"' "$f" || { echo "missing bound generator derivation"; bad=1; }
  grep -q 'basis_commitment' "$f" || { echo "missing basis commitment"; bad=1; }
  grep -q 'Commit_B(v, r)' "$f" || { echo "missing Pedersen vector commitment equation"; bad=1; }
  grep -q 'transition_ref' "$f" || { echo "missing transition references"; bad=1; }
  grep -q 'TRANSITION/1 ABI slot 4' "$f" || { echo "missing exact journal_commitment slot linkage"; bad=1; }
  grep -q 'Transition linkage' "$f" || { echo "missing transition-linkage obligation"; bad=1; }
  grep -q 'same private journal' "$f" || { echo "missing same-journal binding"; bad=1; }
  grep -q 'Pedersen recomputation' "$f" || { echo "missing Pedersen recomputation obligation"; bad=1; }
  grep -q 'P\^n zero-account' "$f" || { echo "missing P^n zero-account obligation"; bad=1; }
  grep -q 'Zero opening' "$f" || { echo "missing zero-opening obligation"; bad=1; }
  grep -q 'A = R \* H' "$f" || { echo "missing aggregate blinding relation"; bad=1; }
  grep -q 'Set commitment' "$f" || { echo "missing atom-set binding"; bad=1; }
  grep -q 'Public ABI (order normative)' "$f" || { echo "missing normative ABI"; bad=1; }
  grep -q 'transition_set_commitment' "$f" || { echo "missing transition set commitment ABI"; bad=1; }
  grep -q 'commitment_set_commitment' "$f" || { echo "missing commitment set commitment ABI"; bad=1; }
  grep -q 'Verifier contract' "$f" || { echo "missing verifier contract"; bad=1; }
  grep -q 'Rejection requirements' "$f" || { echo "missing rejection requirements"; bad=1; }
  grep -q 'invalid, non-canonical, small-subgroup' "$f" || { echo "missing point validation rejection"; bad=1; }
  grep -q 'No reference VNET/1 circuit' "$f" || { echo "missing implementation-status boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "VNET/1 spec carries commitment profile, transition linkage, zero opening, ABI, verifier contract, and rejection boundaries"
}

check_crossrefs() {
  local bad=0
  grep -q '\[VNET/1\](VNET-1.md)' "$APP_INDEX" || { echo "application index missing VNET row"; bad=1; }
  grep -q 'Amount-Vector Netting via Pedersen Commitments' "$APP_INDEX" || { echo "application index title missing"; bad=1; }
  grep -q '\[VNET/1\](VNET-1.md)' "$EVENT" || { echo "EVENT-COMPLETE does not link to VNET"; bad=1; }
  grep -q 'proof MUST link every' "$EVENT" || { echo "EVENT-COMPLETE lacks linkage summary"; bad=1; }
  grep -q 'Pedersen opening back to the exact TRANSITION/1 `journal_commitment`' "$EVENT" || { echo "EVENT-COMPLETE lacks journal commitment linkage summary"; bad=1; }
  grep -q 'zero-opening proof, not inspection of an arbitrary group point' "$EVENT" || { echo "EVENT-COMPLETE lacks zero-opening summary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "application index and EVENT-COMPLETE cross-reference VNET/1"
}

check_corrupt() {
  local m="$TRACES/vnet-mutant.md"
  cp "$VNET" "$m"
  perl -0pi -e 's/`A = R \* H` for a witnessed aggregate blinding/`A` for an inspected aggregate point/' "$m"
  if check_vnet_spec "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing aggregate blinding relation' "$TRACES/_mutant_check.txt" || {
    echo "mutant failed for the wrong reason"
    cat "$TRACES/_mutant_check.txt"
    return 1
  }
  echo "mutant rejected when the zero-opening blinding relation is removed"
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-vnet     check_vnet_spec "$VNET" || fail=1
run 02-crossref check_crossrefs          || fail=1
run 03-corrupt  check_corrupt            || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0034-vnet-pedersen",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Define VNET/1 as a Raw non-enshrined application target for amount-vector netting across posted TRANSITION/1 journals: Pedersen vector commitments with basis-bound generators, explicit transition journal linkage, aggregate zero-opening proof A=R*H, atom-set commitments, verifier contract/context checks, rejection requirements, and EVENT-COMPLETE/index cross-references. No circuit, registry, or R1 tag allocation.",\n'
  printf '  "checks": {\n'
  printf '    "vnet_spec": "%s",\n' "$(grep -q 'VNET/1 spec carries' "$TRACES/01-vnet.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s",\n' "$(grep -q 'cross-reference VNET/1' "$TRACES/02-crossref.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'mutant rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
