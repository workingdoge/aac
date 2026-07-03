#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0038-vnet-link-verifier.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs/applications"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

LINK="$CARGO/reference/vnet_link_verifier.py"
VECTORS="$CARGO/vectors/VNET-LINK-REF-1.json"
VNET="$CARGO/VNET-1.md"
PROFILE_REF="$ROOT/sites/ledger/specs/profiles/reference/vnet_bn254_g1_1.py"

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

check_text() {
  local bad=0
  grep -q 'transition_report' "$LINK" || { echo "missing transition report handling"; bad=1; }
  grep -q 'journal_commitment_mismatch' "$LINK" || { echo "missing journal mismatch rejection"; bad=1; }
  grep -q 'link_certificate_mismatch' "$LINK" || { echo "missing link certificate rejection"; bad=1; }
  grep -q 'profile_ref.check_vector' "$LINK" || { echo "missing delegation to VNET profile checker"; bad=1; }
  grep -q 'vnet_link_verifier.py' "$VNET" || { echo "VNET spec missing link-verifier cross-reference"; bad=1; }
  grep -q 'companion-link' "$VNET" || { echo "VNET spec missing companion-link boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "link verifier and VNET cross-reference carry transition report, journal match, link certificate, and profile-check delegation"
}

check_vectors() {
  python3 "$LINK" check "$VECTORS" --profile-reference "$PROFILE_REF"
}

check_corrupt() {
  local m="$TRACES/corrupt-link.json"
  cp "$VECTORS" "$m"
  python3 - "$m" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path))
doc["vectors"][0]["transition_report"]["accepted"][0]["journal_commitment"] = "bad-journal"
json.dump(doc, open(path, "w"), indent=2, sort_keys=True)
PY
  if python3 "$LINK" check "$m" --profile-reference "$PROFILE_REF" > "$TRACES/_corrupt_check.txt" 2>&1; then
    echo "corrupt link vector unexpectedly passed"
    return 1
  fi
  grep -q 'vnet-link-good-fundraise: FAIL accepted=False reason=journal_commitment_mismatch' "$TRACES/_corrupt_check.txt" || {
    echo "corrupt link vector failed for the wrong reason"
    cat "$TRACES/_corrupt_check.txt"
    return 1
  }
  echo "corrupt link vector rejected when the accepted transition journal_commitment is changed"
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
run 01-text    check_text    || fail=1
run 02-vectors check_vectors || fail=1
run 03-corrupt check_corrupt || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0038-vnet-link-verifier",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a reference VNET transition-link verifier and fixtures: accepted TRANSITION/1 reports, journal_commitment equality, companion link certificates binding opened vectors to transition+basis, and delegation to the VNET-BN254-G1/1 profile checker; reject missing transition refs, journal mismatches, certificate mismatches, and false nets.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'link verifier and VNET cross-reference' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "vectors": "%s",\n' "$(grep -q 'vnet-link-false-net-reject: pass' "$TRACES/02-vectors.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt link vector rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
