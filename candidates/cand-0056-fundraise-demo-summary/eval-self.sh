#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0056-fundraise-demo-summary.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
WORK="$(mktemp -d /private/tmp/aac-fundraise-summary.XXXXXX)"
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

check_structure() {
  local bad=0
  grep -q 'FUNDRAISE_DEMO_SUMMARY_SCHEMA' "$RUNNER/src/index.mjs" \
    || { echo "missing summary schema"; bad=1; }
  grep -q 'buildFundraiseDemoSummary' "$RUNNER/src/index.mjs" \
    || { echo "missing summary builder"; bad=1; }
  grep -q -- '--summary' "$RUNNER/bin/fundraise-demo.mjs" \
    || { echo "CLI missing summary flag"; bad=1; }
  grep -q 'production recursive/on-chain VNET proof verification remains a separate target' "$RUNNER/src/index.mjs" \
    || { echo "missing verifier-boundary caveat"; bad=1; }
  grep -q 'public_inputs' "$RUNNER/src/index.d.ts" \
    || { echo "types missing public inputs"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runner exposes a deterministic summary projection with explicit verifier boundary"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/README.md\tfundraise-demo-runner/README.md' "$CAND_DIR/LANDING" \
    || { echo "missing README landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing JS landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing type landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/bin/fundraise-demo.mjs\tfundraise-demo-runner/bin/fundraise-demo.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing CLI landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing test landing"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  ! find "$CAND_DIR/cargo" -path '*/target/*' -type f | grep -q . \
    || { echo "generated target artifact included"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo-runner only; support packages are eval fixtures"
}

check_unit() {
  "$NODE_BIN" "$RUNNER/test/run-tests.mjs"
}

check_cli_help() {
  "$NODE_BIN" "$RUNNER/bin/fundraise-demo.mjs" --help
}

check_summary_projection() {
  CAND_DIR="$CAND_DIR" SUMMARY_WORK="$WORK" NODE_BIN="$NODE_BIN" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const api = await import(pathToFileURL(resolve(process.env.CAND_DIR, "cargo/fundraise-demo-runner/src/index.mjs")));
const {
  FUNDRAISE_DEMO_SUMMARY_SCHEMA,
  buildFundraiseDemoSummary,
  runFundraiseDemo,
} = api;

const repoRoot = resolve(process.env.CAND_DIR, "cargo");
const circuitDir = resolve(process.env.SUMMARY_WORK, "circuit");
await mkdir(circuitDir, { recursive: true });
await writeFile(resolve(circuitDir, "Nargo.toml"), "[package]\nname = \"fake\"\n");
await writeFile(resolve(circuitDir, "Prover.toml.example"), "accepted = true\n");

const receipt = await runFundraiseDemo({
  repo_root: repoRoot,
  circuit_dir: circuitDir,
  provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
  run_command: async (command) => {
    if (command.step === "prepare") {
      await writeFile(command.args[command.args.indexOf("-p") + 1], new Uint8Array([1, 2, 3]));
      await writeFile(command.args[command.args.indexOf("-v") + 1], new Uint8Array([4, 5, 6]));
    }
    if (command.step === "prove") {
      await writeFile(command.args[command.args.indexOf("-o") + 1], new Uint8Array([7, 8, 9]));
    }
    return { exit_code: 0, stdout: `${command.step}: ok\n` };
  },
});

assert.equal(receipt.summary.schema, FUNDRAISE_DEMO_SUMMARY_SCHEMA);
assert.equal(receipt.summary.status, "authorized-pending-signature");
assert.equal(receipt.summary.round_id, "aac-seed-2026-001");
assert.equal(receipt.summary.issuer_name, "issuer-a.private-row");
assert.equal(receipt.summary.economics.settlement_amount_total, 1500);
assert.equal(receipt.summary.economics.issued_unit_total, 150);
assert.equal(receipt.summary.economics.recipient_count, 2);
assert.equal(receipt.summary.commitments.transition_set, receipt.public_inputs.transition_set_commitment);
assert.equal(receipt.summary.proof.proof_digest, receipt.provekit.proof_digest);
assert.equal(receipt.summary.workflow.signature_status, "pending");
assert.equal(receipt.summary.settlement.total_supply, null);
assert.deepEqual(buildFundraiseDemoSummary(receipt), receipt.summary);
console.log(JSON.stringify(receipt.summary, null, 2));
JS
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-14s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
[[ -x "$NODE_BIN" ]] || { echo "node runtime unavailable"; fail=1; }
run 01-structure check_structure         || fail=1
run 02-scope     check_scope             || fail=1
run 03-unit      check_unit              || fail=1
run 04-cli-help  check_cli_help          || fail=1
run 05-summary   check_summary_projection || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0056-fundraise-demo-summary",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a deterministic presentation summary artifact to the fundraise demo runner.",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n' "$(grep -q 'deterministic summary projection' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'demo-runner only' "$TRACES/02-scope.txt" && echo pass || echo fail)"
  printf '    "unit": "%s",\n' "$(grep -q 'fundraise-demo-runner tests: pass' "$TRACES/03-unit.txt" && echo pass || echo fail)"
  printf '    "cli_help": "%s",\n' "$(grep -q -- '--summary' "$TRACES/04-cli-help.txt" && echo pass || echo fail)"
  printf '    "summary_projection": "%s"\n' "$(grep -q 'authorized-pending-signature' "$TRACES/05-summary.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
