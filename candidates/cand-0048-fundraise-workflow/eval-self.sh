#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0048-fundraise-workflow.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
WORKFLOW="$CARGO/fundraise-workflow"
SPEC="$CARGO/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi

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
  [[ -n "$NODE_BIN" && -x "$NODE_BIN" ]] || { echo "node runtime unavailable"; bad=1; }
  grep -q 'authorizeFundraiseWorkflow' "$WORKFLOW/src/index.mjs" || { echo "missing workflow entrypoint"; bad=1; }
  grep -q 'verifyVerifierReceipt' "$WORKFLOW/src/index.mjs" || { echo "missing verifier receipt check"; bad=1; }
  grep -q 'require_live_proof' "$WORKFLOW/src/index.mjs" || { echo "missing live-proof policy guard"; bad=1; }
  grep -q 'FundraiseMintSettlement.settle' "$WORKFLOW/README.md" || { echo "README missing settlement action target"; bad=1; }
  grep -q 'does not import the CRE SDK' "$WORKFLOW/README.md" || { echo "README missing CRE dependency boundary"; bad=1; }
  grep -q 'fundraise-workflow' "$SPEC" || { echo "spec missing workflow status"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "workflow entrypoint, verifier guard, live-proof guard, and boundary text are present"
}

check_runtime() {
  "$NODE_BIN" "$WORKFLOW/test/run-tests.mjs"
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const workflow = await import(pathToFileURL(`${cand}/cargo/fundraise-workflow/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;
const verifier = workflow.buildDemoVerifierReceipt({ packet });
const receipt = workflow.authorizeFundraiseWorkflow({ packet, verifier_receipt: verifier });
assert.equal(receipt.accepted, true);

const proofMismatch = structuredClone(verifier);
proofMismatch.packet_commitment = "0x0000000000000000000000000000000000000000000000000000000000000000";
assert.equal(workflow.verifyVerifierReceipt(proofMismatch, { packet }).reason, "verifier_receipt_digest_mismatch");

const livePolicy = workflow.createWorkflowPolicy({ require_live_proof: true });
assert.equal(workflow.authorizeFundraiseWorkflow({ packet, verifier_receipt: verifier, policy: livePolicy }).reason, "live_proof_required");

const tampered = structuredClone(receipt);
tampered.settlement_action.args.signature = "0x" + "11".repeat(65);
assert.equal(workflow.verifyWorkflowReceipt(tampered).reason, "workflow_receipt_digest_mismatch");
console.log("workflow rejects verifier tamper, simulated proof under live policy, and action tamper");
JS
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
run 02-runtime check_runtime || fail=1
run 03-corrupt check_corrupt || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0048-fundraise-workflow",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a dependency-free fundraise workflow core that composes verifier receipts with the authorizer seam and emits settlement actions.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'workflow entrypoint, verifier guard' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-workflow tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'workflow rejects verifier tamper' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
