#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0039-fundraise-demo-packet.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs/applications"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

CHECKER="$CARGO/reference/fundraise_demo.py"
VECTORS="$CARGO/vectors/FUNDRAISE-DEMO-1.json"
SPEC="$CARGO/FUNDRAISE-CLEARING-1.md"
VNET_REF="$ROOT/sites/ledger/specs/applications/reference/vnet_link_verifier.py"
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
  grep -q 'settlement_report' "$CHECKER" || { echo "checker missing settlement report handling"; bad=1; }
  grep -q 'admissibility_report' "$CHECKER" || { echo "checker missing admissibility report handling"; bad=1; }
  grep -q 'mint_authorization' "$CHECKER" || { echo "checker missing mint authorization binding"; bad=1; }
  grep -q 'vnet_ref.check_case' "$CHECKER" || { echo "checker missing VNET delegation"; bad=1; }
  grep -q 'FUNDRAISE-DEMO-1.json' "$SPEC" || { echo "spec missing demo vector cross-reference"; bad=1; }
  grep -q 'No reference circuit, native verifier, verifier contract' "$SPEC" || { echo "spec boundary no longer names non-implemented production surfaces"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise demo checker/spec carry reports, mint binding, VNET delegation, and implementation boundary"
}

check_vectors() {
  python3 "$CHECKER" check "$VECTORS" --vnet-reference "$VNET_REF" --profile-reference "$PROFILE_REF"
}

check_corrupt() {
  local m="$TRACES/corrupt-settlement.json"
  cp "$VECTORS" "$m"
  python3 - "$m" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path))
doc["vectors"][0]["packet"]["settlement_report"]["accepted"][0]["amount"] += 1
json.dump(doc, open(path, "w"), indent=2, sort_keys=True)
PY
  if python3 "$CHECKER" check "$m" --vnet-reference "$VNET_REF" --profile-reference "$PROFILE_REF" > "$TRACES/_corrupt_check.txt" 2>&1; then
    echo "corrupt settlement vector unexpectedly passed"
    return 1
  fi
  grep -q 'fundraise-demo-good: FAIL accepted=False reason=settlement_amount_mismatch' "$TRACES/_corrupt_check.txt" || {
    echo "corrupt settlement vector failed for the wrong reason"
    cat "$TRACES/_corrupt_check.txt"
    return 1
  }
  echo "corrupt settlement vector rejected when a trusted settlement amount changes"
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
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0039-fundraise-demo-packet",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker binding round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; reject price, settlement, token, and VNET failures.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'fundraise demo checker/spec' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "vectors": "%s",\n' "$(grep -q 'fundraise-demo-vnet-false-net-reject: pass' "$TRACES/02-vectors.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt settlement vector rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
