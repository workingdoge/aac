#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0049-provekit-receipt-adapter.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
ADAPTER="$CARGO/fundraise-provekit-adapter"
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
  grep -q 'buildProveKitVerifierReceipt' "$ADAPTER/src/index.mjs" || { echo "missing receipt builder"; bad=1; }
  grep -q 'verifyProveKitVerifierReceipt' "$ADAPTER/src/index.mjs" || { echo "missing receipt verifier"; bad=1; }
  grep -q 'provekit-whir' "$ADAPTER/src/index.mjs" || { echo "missing WHIR proof system"; bad=1; }
  grep -q 'does not run ProveKit' "$ADAPTER/README.md" || { echo "README missing ProveKit boundary"; bad=1; }
  grep -q 'require_live_proof' "$ADAPTER/README.md" || { echo "README missing live workflow binding"; bad=1; }
  grep -q 'fundraise-provekit-adapter' "$SPEC" || { echo "spec missing adapter status"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "ProveKit adapter receipt builder, verifier, proof-system guards, and boundary text are present"
}

check_runtime() {
  "$NODE_BIN" "$ADAPTER/test/run-tests.mjs"
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const adapter = await import(pathToFileURL(`${cand}/cargo/fundraise-provekit-adapter/src/index.mjs`));
const workflow = await import(pathToFileURL(`${cand}/cargo/fundraise-workflow/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;
const provekit = {
  accepted: true,
  proof_system: "provekit-whir",
  mode: "service",
  proof: "proof-bytes",
  public_inputs: packet.public_inputs,
  verifier_key_digest: "0x" + "cd".repeat(32),
  timings_ms: { prove: 400, verify: 40 },
};
const receipt = adapter.buildProveKitVerifierReceipt({ packet, provekit });
const policy = workflow.createWorkflowPolicy({ require_live_proof: true });
assert.equal(workflow.authorizeFundraiseWorkflow({ packet, verifier_receipt: receipt, policy }).accepted, true);
const tampered = structuredClone(receipt);
tampered.verifier_key_digest = "0x" + "ef".repeat(32);
assert.equal(adapter.verifyProveKitVerifierReceipt(tampered, { packet }).reason, "verifier_receipt_digest_mismatch");
assert.throws(() => adapter.buildProveKitVerifierReceipt({
  packet,
  provekit: { ...provekit, accepted: true, timings_ms: { prove: -1 } },
}), /bad_timing/);
console.log("adapter rejects verifier-key tamper and bad timings while satisfying live-proof workflow policy");
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
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0049-provekit-receipt-adapter",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a dependency-free ProveKit verifier receipt adapter for fundraise-workflow live-proof authorization.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'ProveKit adapter receipt builder' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-provekit-adapter tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'adapter rejects verifier-key tamper' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
