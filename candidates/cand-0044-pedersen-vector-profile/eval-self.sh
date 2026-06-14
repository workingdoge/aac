#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0044-pedersen-vector-profile.
# PEDERSEN-VECTOR/1 is a Raw profile concretizing VNET/1 §2/§9. Evidence is
# structural: the profile must carry the concrete group (Grumpkin), the
# generator derivation rule, the MSM-ONLY aggregation discipline (the measured
# backend constraint: MultiScalarMul yes, EmbeddedCurveAdd no), the zero-opening
# as a single MSM, bounded coordinates, conformance vectors, and target
# identity; the index + VNET/1 must reference it; and a mutant that drops the
# MSM-only constraint must be rejected.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
PROF="$CAND_DIR/cargo/sites/ledger/specs/profiles"
APP="$CAND_DIR/cargo/sites/ledger/specs/applications"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

PROFILE="$PROF/PEDERSEN-VECTOR-1.md"
PROF_INDEX="$PROF/README.md"
VNET="$APP/VNET-1.md"

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

check_profile() {
  local f="$1" bad=0
  grep -q 'PEDERSEN-VECTOR/1' "$f" || { echo "missing profile name"; bad=1; }
  grep -q 'Profile for VNET/1' "$f" || { echo "missing VNET/1 profile scope"; bad=1; }
  grep -q 'Grumpkin' "$f" || { echo "missing concrete group (Grumpkin)"; bad=1; }
  grep -q 'EmbeddedCurvePoint' "$f" || { echo "missing point encoding"; bad=1; }
  grep -q 'try-and-increment hash-to-curve' "$f" || { echo "missing generator derivation rule"; bad=1; }
  grep -q 'aac/vnet/1' "$f" || { echo "missing domain-separated generator binding"; bad=1; }
  grep -q 'verifier-determined, not prover-chosen' "$f" || { echo "missing generator-trust rule"; bad=1; }
  grep -q 'no known discrete-log relation' "$f" || { echo "missing DL-freeness requirement"; bad=1; }
  grep -q 'Commit_B(v, r)' "$f" || { echo "missing commitment form"; bad=1; }
  grep -q 'multi_scalar_mul' "$f" || { echo "missing MSM commitment constructor"; bad=1; }
  # The load-bearing constraint of this profile:
  grep -q 'MSM-only aggregation' "$f" || { echo "missing MSM-only aggregation rule"; bad=1; }
  grep -q 'EmbeddedCurveAdd' "$f" || { echo "missing the no-point-add finding"; bad=1; }
  grep -q 'MUST NOT rely on a point-addition opcode' "$f" || { echo "missing point-addition-absent statement"; bad=1; }
  grep -q 'Summing committed points' "$f" || { echo "missing unit-scalar point summation rule"; bad=1; }
  grep -q 'Zero opening as a single MSM' "$f" || { echo "missing single-MSM zero opening"; bad=1; }
  grep -q 'net_j == 0' "$f" || { echo "missing per-dimension nullity"; bad=1; }
  grep -q 'A = R \* H' "$f" || { echo "missing pure-blinding opening relation"; bad=1; }
  grep -q 'RANGE constraint' "$f" || { echo "missing bounded-coordinate RANGE rule"; bad=1; }
  grep -q 'No scalar wraparound' "$f" || { echo "missing homomorphism-exactness bound"; bad=1; }
  grep -q 'Conformance vectors' "$f" || { echo "missing conformance vectors"; bad=1; }
  grep -q 'false net' "$f" || { echo "missing false-net soundness case"; bad=1; }
  grep -q 'Target identity' "$f" || { echo "missing target-identity clause"; bad=1; }
  grep -q 'pedersen-vector/1' "$f" || { echo "missing profile_id"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "PEDERSEN-VECTOR/1 carries group, generators, MSM-only aggregation, single-MSM zero opening, bounded coordinates, conformance vectors, and target identity"
}

check_crossrefs() {
  local bad=0
  grep -q '\[PEDERSEN-VECTOR/1\](PEDERSEN-VECTOR-1.md)' "$PROF_INDEX" || { echo "profiles index missing PEDERSEN-VECTOR row"; bad=1; }
  grep -q 'Grumpkin Pedersen vector commitments (MSM-only)' "$PROF_INDEX" || { echo "profiles index scope missing"; bad=1; }
  grep -q 'PEDERSEN-VECTOR/1\](../profiles/PEDERSEN-VECTOR-1.md)' "$VNET" || { echo "VNET/1 does not reference the profile"; bad=1; }
  grep -q 'The concrete vector-commitment profile is assigned' "$VNET" || { echo "VNET/1 §9 does not assign the profile"; bad=1; }
  grep -q 'EmbeddedCurveAdd' "$VNET" || { echo "VNET/1 §9 does not record the MSM-only finding"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "profiles index and VNET/1 cross-reference PEDERSEN-VECTOR/1"
}

check_corrupt() {
  local m="$TRACES/profile-mutant.md"
  cp "$PROFILE" "$m"
  # Remove the load-bearing MSM-only finding (the EmbeddedCurveAdd absence).
  perl -0pi -e 's/but \*\*not\*\* `EmbeddedCurveAdd`/and also point addition/g' "$m"
  if check_profile "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing the no-point-add finding' "$TRACES/_mutant_check.txt" || {
    echo "mutant failed for the wrong reason"
    cat "$TRACES/_mutant_check.txt"
    return 1
  }
  echo "mutant rejected when the MSM-only (no EmbeddedCurveAdd) constraint is removed"
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
run 01-profile  check_profile "$PROFILE" || fail=1
run 02-crossref check_crossrefs          || fail=1
run 03-corrupt  check_corrupt            || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0044-pedersen-vector-profile",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Concretize VNET/1 into the PEDERSEN-VECTOR/1 profile: Grumpkin group + EmbeddedCurvePoint encoding, domain-separated try-and-increment generator derivation (verifier-determined), the Commit_B(v,r) MSM form, the MSM-ONLY aggregation discipline grounded in a measured backend capability (ProveKit implements MultiScalarMul but not EmbeddedCurveAdd), the zero-opening proven as a single MSM with per-dimension nullity, bounded non-negative coordinates with no scalar wraparound, conformance vectors incl. the false-net soundness case, and target identity. Index + VNET/1 §2/§9 reference it; no circuit or R1 tag allocation.",\n'
  printf '  "checks": {\n'
  printf '    "profile": "%s",\n' "$(grep -q 'PEDERSEN-VECTOR/1 carries' "$TRACES/01-profile.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s",\n' "$(grep -q 'cross-reference PEDERSEN-VECTOR/1' "$TRACES/02-crossref.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'mutant rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
