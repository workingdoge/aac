#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0051-pedersen-vector-msm-profile.
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
  grep -q 'ProveKit-oriented vector-commitment substrate' "$f" || { echo "missing ProveKit-oriented scope"; bad=1; }
  grep -q 'VNET-BN254-G1/1 profile remains' "$f" || { echo "missing BN254 coexistence boundary"; bad=1; }
  grep -q 'Grumpkin' "$f" || { echo "missing concrete group"; bad=1; }
  grep -q 'EmbeddedCurvePoint' "$f" || { echo "missing point encoding"; bad=1; }
  grep -q 'try-and-increment hash-to-curve' "$f" || { echo "missing generator derivation rule"; bad=1; }
  grep -q 'verifier-determined, not prover-chosen' "$f" || { echo "missing generator trust rule"; bad=1; }
  grep -q 'no known discrete-log relation' "$f" || { echo "missing DL-freeness requirement"; bad=1; }
  grep -q 'Commit_B(v, r)' "$f" || { echo "missing commitment form"; bad=1; }
  grep -q 'multi_scalar_mul' "$f" || { echo "missing MSM constructor"; bad=1; }
  grep -q 'MSM-only aggregation' "$f" || { echo "missing MSM-only aggregation"; bad=1; }
  grep -q 'but \*\*not\*\* `EmbeddedCurveAdd`' "$f" || { echo "missing no-EmbeddedCurveAdd finding"; bad=1; }
  grep -q 'MUST NOT rely on a point-addition opcode' "$f" || { echo "missing point-add refusal"; bad=1; }
  grep -q 'Summing committed points' "$f" || { echo "missing unit-scalar point summation"; bad=1; }
  grep -q 'Zero opening as a single MSM' "$f" || { echo "missing single-MSM zero opening"; bad=1; }
  grep -q 'net_j == 0' "$f" || { echo "missing per-dimension nullity"; bad=1; }
  grep -q 'A = R \* H' "$f" || { echo "missing pure-blinding opening"; bad=1; }
  grep -q 'RANGE constraint' "$f" || { echo "missing bounded-coordinate RANGE rule"; bad=1; }
  grep -q 'No scalar wraparound' "$f" || { echo "missing no-wraparound rule"; bad=1; }
  grep -q 'false net' "$f" || { echo "missing false-net soundness case"; bad=1; }
  grep -q 'pedersen-vector/1' "$f" || { echo "missing profile_id"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "PEDERSEN-VECTOR/1 carries ProveKit Grumpkin MSM profile obligations and preserves BN254 coexistence"
}

check_crossrefs() {
  local bad=0
  grep -q '\[VNET-BN254-G1/1\](VNET-BN254-G1-1.md)' "$PROF_INDEX" || { echo "profiles index dropped BN254 row"; bad=1; }
  grep -q '\[PEDERSEN-VECTOR/1\](PEDERSEN-VECTOR-1.md)' "$PROF_INDEX" || { echo "profiles index missing PEDERSEN row"; bad=1; }
  grep -q 'VNET-BN254-G1/1' "$VNET" || { echo "VNET/1 dropped BN254 status"; bad=1; }
  grep -q 'PEDERSEN-VECTOR/1' "$VNET" || { echo "VNET/1 missing PEDERSEN status"; bad=1; }
  grep -q 'MultiScalarMul' "$VNET" || { echo "VNET/1 missing ProveKit MSM capability"; bad=1; }
  grep -q 'EmbeddedCurveAdd' "$VNET" || { echo "VNET/1 missing no-point-add finding"; bad=1; }
  grep -q 'does not replace the BN254' "$VNET" || { echo "VNET/1 missing coexistence statement"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "profiles index and VNET/1 carry both BN254 reference and PEDERSEN ProveKit paths"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md\tsites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md' "$CAND_DIR/LANDING" || { echo "missing profile landing"; bad=1; }
  grep -qx $'cargo/sites/ledger/specs/profiles/README.md\tsites/ledger/specs/profiles/README.md' "$CAND_DIR/LANDING" || { echo "missing index landing"; bad=1; }
  grep -qx $'cargo/sites/ledger/specs/applications/VNET-1.md\tsites/ledger/specs/applications/VNET-1.md' "$CAND_DIR/LANDING" || { echo "missing VNET landing"; bad=1; }
  ! grep -q 'world-app/provekit-vnet' "$CAND_DIR/LANDING" || { echo "prototype circuit should not land in this candidate"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is limited to profile text, index, and VNET implementation-status cross-reference"
}

check_corrupt() {
  local m="$TRACES/profile-mutant.md"
  cp "$PROFILE" "$m"
  perl -0pi -e 's/but \*\*not\*\* `EmbeddedCurveAdd`/and also point addition/g' "$m"
  if check_profile "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing no-EmbeddedCurveAdd finding' "$TRACES/_mutant_check.txt" || {
    echo "mutant failed for the wrong reason"
    cat "$TRACES/_mutant_check.txt"
    return 1
  }
  echo "mutant rejected when no-EmbeddedCurveAdd finding is removed"
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
run 03-scope    check_scope              || fail=1
run 04-corrupt  check_corrupt            || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0051-pedersen-vector-msm-profile",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Port the ProveKit MSM-only PEDERSEN-VECTOR/1 profile into vnet-fundraising while preserving the existing BN254 reference profile and leaving the prototype circuit unlanded.",\n'
  printf '  "checks": {\n'
  printf '    "profile": "%s",\n' "$(grep -q 'ProveKit Grumpkin MSM' "$TRACES/01-profile.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s",\n' "$(grep -q 'both BN254 reference and PEDERSEN' "$TRACES/02-crossref.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'landing scope is limited' "$TRACES/03-scope.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'mutant rejected' "$TRACES/04-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
