#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0035-vnet-fundraising.
# FUNDRAISE-CLEARING/1 is a Raw application-target spec. Evidence is structural:
# the spec must bind paid subscriptions to private issuer books, cap-table roots,
# VNET zero-opening, nullifiers, and token issuance context, while keeping
# external settlement/admissibility adapters outside the proof.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs/applications"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

SPEC="$CARGO/FUNDRAISE-CLEARING-1.md"
APP_INDEX="$CARGO/README.md"

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

check_spec() {
  local f="$1" bad=0
  grep -q 'Application target (not enshrined)' "$f" || { echo "missing non-enshrined marker"; bad=1; }
  grep -q 'legal equity' "$f" || { echo "missing legal-status boundary"; bad=1; }
  grep -q 'TRANSITION/1' "$f" || { echo "missing TRANSITION composition"; bad=1; }
  grep -q 'NULLIFY/1' "$f" || { echo "missing NULLIFY composition"; bad=1; }
  grep -q 'VNET/1' "$f" || { echo "missing VNET composition"; bad=1; }
  grep -q 'RoundPolicy' "$f" || { echo "missing round policy object"; bad=1; }
  grep -q 'SubscriptionAtom' "$f" || { echo "missing subscription atom"; bad=1; }
  grep -q 'Settlement binding' "$f" || { echo "missing settlement binding obligation"; bad=1; }
  grep -q 'Payment/admissibility context' "$f" || { echo "missing external-context boundary"; bad=1; }
  grep -q 'Issue-price arithmetic' "$f" || { echo "missing price arithmetic"; bad=1; }
  grep -q 'Round caps' "$f" || { echo "missing cap checks"; bad=1; }
  grep -q 'Private issuer accounting' "$f" || { echo "missing private books update"; bad=1; }
  grep -q 'Cap-table root update' "$f" || { echo "missing cap-table root update"; bad=1; }
  grep -q 'VNET amount closure' "$f" || { echo "missing VNET amount closure"; bad=1; }
  grep -q 'MUST establish aggregate zero-opening' "$f" || { echo "missing zero-opening requirement"; bad=1; }
  grep -q 'Nullifier discipline' "$f" || { echo "missing nullifier discipline"; bad=1; }
  grep -q 'Token issuance binding' "$f" || { echo "missing token issuance binding"; bad=1; }
  grep -q 'Public ABI (order normative)' "$f" || { echo "missing normative ABI"; bad=1; }
  grep -q 'vnet_public_commitment' "$f" || { echo "missing VNET ABI commitment"; bad=1; }
  grep -q 'mint_recipient_set_commitment' "$f" || { echo "missing mint recipient binding"; bad=1; }
  grep -q 'Verifier contract' "$f" || { echo "missing verifier contract"; bad=1; }
  grep -q 'Rejection requirements' "$f" || { echo "missing rejection requirements"; bad=1; }
  grep -q 'No reference circuit' "$f" || { echo "missing implementation-status boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "FUNDRAISE-CLEARING/1 spec carries settlement, private books, cap-table, VNET, nullifier, mint, ABI, verifier, and boundary obligations"
}

check_index() {
  local bad=0
  grep -q '\[FUNDRAISE-CLEARING/1\](FUNDRAISE-CLEARING-1.md)' "$APP_INDEX" || { echo "application index missing FUNDRAISE row"; bad=1; }
  grep -q 'Private Balance-Sheet Fundraising Settlement' "$APP_INDEX" || { echo "application index title missing"; bad=1; }
  grep -q '\[VNET/1\](VNET-1.md)' "$APP_INDEX" || { echo "application index lost VNET row"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "application index references FUNDRAISE-CLEARING/1 and preserves VNET/1"
}

check_corrupt() {
  local m="$TRACES/fundraise-mutant.md"
  cp "$SPEC" "$m"
  perl -0pi -e 's/aggregate zero-opening; inspecting a Pedersen\n   aggregate point is not sufficient/aggregate point inspection/' "$m"
  if check_spec "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing zero-opening requirement' "$TRACES/_mutant_check.txt" || {
    echo "mutant failed for the wrong reason"
    cat "$TRACES/_mutant_check.txt"
    return 1
  }
  echo "mutant rejected when the VNET zero-opening requirement is removed"
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
run 01-spec    check_spec "$SPEC" || fail=1
run 02-index   check_index        || fail=1
run 03-corrupt check_corrupt      || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0035-vnet-fundraising",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Define FUNDRAISE-CLEARING/1 as a Raw non-enshrined application target for private-balance-sheet fundraising: paid subscriptions bind to trusted settlement/admissibility reports, private issuer accounting, cap-table root updates, VNET/1 zero-opening over linked TRANSITION/1 journals, subscription nullifiers, and restricted token issuance context. No circuit, contract, external adapter, legal-equity claim, or concrete VNET curve/profile.",\n'
  printf '  "checks": {\n'
  printf '    "fundraise_spec": "%s",\n' "$(grep -q 'FUNDRAISE-CLEARING/1 spec carries' "$TRACES/01-spec.txt" && echo pass || echo fail)"
  printf '    "app_index": "%s",\n' "$(grep -q 'application index references' "$TRACES/02-index.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'mutant rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
