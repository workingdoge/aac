#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0037-vnet-profile-vectors.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

PROFILE="$CARGO/profiles/VNET-BN254-G1-1.md"
PROFILE_INDEX="$CARGO/profiles/README.md"
REF="$CARGO/profiles/reference/vnet_bn254_g1_1.py"
VECTORS="$CARGO/profiles/vectors/VNET-BN254-G1-1.json"
VNET="$CARGO/applications/VNET-1.md"

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
  local bad=0
  grep -q 'VNET-BN254-G1/1' "$PROFILE" || { echo "missing profile name"; bad=1; }
  grep -q 'BN254 G1' "$PROFILE" || { echo "missing group"; bad=1; }
  grep -q 'uncompressed affine `0x04 || x_be32 || y_be32`' "$PROFILE" || { echo "missing point encoding"; bad=1; }
  grep -q 'amount coordinate' "$PROFILE" && grep -q '2\^64' "$PROFILE" || { echo "missing amount bound"; bad=1; }
  grep -q 'hash_to_curve("aac/vnet-bn254-g1/1/H"' "$PROFILE" || { echo "missing H derivation"; bad=1; }
  grep -q 'hash_to_curve("aac/vnet-bn254-g1/1/G"' "$PROFILE" || { echo "missing G derivation"; bad=1; }
  grep -q 'Commit_B(v, rho)' "$PROFILE" || { echo "missing commitment rule"; bad=1; }
  grep -q 'A = R\*H' "$PROFILE" || { echo "missing zero-opening rule"; bad=1; }
  grep -q 'reference/vnet_bn254_g1_1.py' "$PROFILE" || { echo "missing reference checker link"; bad=1; }
  grep -q 'VNET-BN254-G1/1' "$PROFILE_INDEX" || { echo "profile index missing row"; bad=1; }
  grep -q 'VNET-BN254-G1/1' "$VNET" || { echo "VNET spec missing profile cross-ref"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "profile/index/VNET cross-references carry BN254 group, encoding, generator derivation, commitment, and zero-opening rules"
}

check_vectors() {
  python3 "$REF" check "$VECTORS"
}

check_corrupt() {
  local m="$TRACES/corrupt-vectors.json"
  cp "$VECTORS" "$m"
  python3 - "$m" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path))
doc["vectors"][0]["atoms"][0]["credit"][0] -= 1
json.dump(doc, open(path, "w"), indent=2, sort_keys=True)
PY
  if python3 "$REF" check "$m" > "$TRACES/_corrupt_check.txt" 2>&1; then
    echo "corrupt vector unexpectedly passed"
    return 1
  fi
  grep -q 'fundraise-good-batch: FAIL' "$TRACES/_corrupt_check.txt" || {
    echo "corrupt vector failed for the wrong reason"
    cat "$TRACES/_corrupt_check.txt"
    return 1
  }
  echo "corrupt vector rejected when a committed amount is changed without recomputing commitments"
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
run 01-profile check_profile || fail=1
run 02-vectors check_vectors || fail=1
run 03-corrupt check_corrupt || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0037-vnet-profile-vectors",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Define VNET-BN254-G1/1 as the first concrete VNET/1 Pedersen vector-commitment profile, with BN254 G1 point encoding, deterministic generator derivation, u64 amount bounds, executable generated conformance vectors, and a reference checker covering accepted fundraising batch, mixed-basis rejection, missing transition-link rejection, and false-net zero-opening rejection.",\n'
  printf '  "checks": {\n'
  printf '    "profile": "%s",\n' "$(grep -q 'profile/index/VNET cross-references' "$TRACES/01-profile.txt" && echo pass || echo fail)"
  printf '    "vectors": "%s",\n' "$(grep -q 'fundraise-false-net-reject: pass' "$TRACES/02-vectors.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt vector rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
