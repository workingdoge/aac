#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0053-provekit-cli-adapter.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
ADAPTER="$CARGO/fundraise-provekit-adapter"
PROVEKIT_PKG="$CARGO/world-app/provekit-vnet"
WORK="$(mktemp -d /private/tmp/aac-provekit-cli-adapter.XXXXXX)"
RUN_PKG="$WORK/provekit-vnet"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi
PROVEKIT_BIN="${PROVEKIT_BIN:-}"

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

resolve_toolchain() {
  local p
  [[ -n "$NODE_BIN" && -x "$NODE_BIN" ]] || { echo "node runtime unavailable"; return 1; }
  if [[ -z "$PROVEKIT_BIN" ]]; then
    while IFS= read -r p; do
      case "$p" in
        *-provekit-cli-1.0.0/bin/provekit-cli) PROVEKIT_BIN="$p"; break ;;
      esac
    done < <(find /nix/store -maxdepth 4 -path '*/bin/provekit-cli' -type f 2>/dev/null | sort)
  fi
  [[ -x "$PROVEKIT_BIN" ]] || { echo "provekit-cli binary not found in /nix/store"; return 1; }
  "$NODE_BIN" --version
  "$PROVEKIT_BIN" --help | head -n 1
}

check_structure() {
  local bad=0
  grep -q 'runProveKitNativeCli' "$ADAPTER/src/index.mjs" \
    || { echo "missing native CLI runner export"; bad=1; }
  grep -q 'buildProveKitVerifierReceiptFromNativeCli' "$ADAPTER/src/index.mjs" \
    || { echo "missing native CLI receipt builder"; bad=1; }
  grep -q 'prepare.*prove.*verify' "$ADAPTER/README.md" \
    || { echo "README missing native CLI flow"; bad=1; }
  grep -q 'run_command' "$ADAPTER/src/index.mjs" \
    || { echo "missing injectable command seam"; bad=1; }
  grep -q 'provekit_cli_verify_failed' "$ADAPTER/test/run-tests.mjs" \
    || { echo "missing verify-failure rejection test"; bad=1; }
  ! grep -q 'does not run ProveKit' "$ADAPTER/README.md" \
    || { echo "README still claims the adapter cannot run ProveKit"; bad=1; }
  grep -q 'proof_file_missing' "$ADAPTER/src/index.mjs" \
    || { echo "missing proof-file digest guard"; bad=1; }
  grep -q 'verifier_key_file_missing' "$ADAPTER/src/index.mjs" \
    || { echo "missing verifier-key digest guard"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "adapter exposes native CLI prepare/prove/verify runner, injectable seam, digest guards, and rejection tests"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-provekit-adapter/package.json\tfundraise-provekit-adapter/package.json' "$CAND_DIR/LANDING" \
    || { echo "missing package.json landing"; bad=1; }
  grep -qx $'cargo/fundraise-provekit-adapter/README.md\tfundraise-provekit-adapter/README.md' "$CAND_DIR/LANDING" \
    || { echo "missing README landing"; bad=1; }
  grep -qx $'cargo/fundraise-provekit-adapter/src/index.mjs\tfundraise-provekit-adapter/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing JS landing"; bad=1; }
  grep -qx $'cargo/fundraise-provekit-adapter/src/index.d.ts\tfundraise-provekit-adapter/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing type landing"; bad=1; }
  grep -qx $'cargo/fundraise-provekit-adapter/test/run-tests.mjs\tfundraise-provekit-adapter/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing test landing"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  ! find "$CAND_DIR/cargo" -path '*/target/*' -type f | grep -q . \
    || { echo "generated target artifact included"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is adapter package only; no generated artifacts or review-guard paths"
}

check_unit() {
  "$NODE_BIN" "$ADAPTER/test/run-tests.mjs"
}

prepare_workdir() {
  cp -R "$PROVEKIT_PKG" "$RUN_PKG"
  cp "$RUN_PKG/Prover.toml.example" "$RUN_PKG/Prover.toml"
  mkdir -p "$WORK/home/nargo"
  echo "prepared temporary VNET package at $RUN_PKG"
}

check_real_cli_receipt() {
  HOME="$WORK/home" AAC_CAND_DIR="$CAND_DIR" AAC_RUN_PKG="$RUN_PKG" PROVEKIT_BIN="$PROVEKIT_BIN" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const runPkg = process.env.AAC_RUN_PKG;
const provekitBin = process.env.PROVEKIT_BIN;
const adapter = await import(pathToFileURL(`${cand}/cargo/fundraise-provekit-adapter/src/index.mjs`));
const workflow = await import(pathToFileURL(`${cand}/cargo/fundraise-workflow/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;

const receipt = await adapter.buildProveKitVerifierReceiptFromNativeCli({
  packet,
  cli: {
    provekit_bin: provekitBin,
    circuit_dir: runPkg,
    cwd: runPkg,
    prover_toml: "Prover.toml",
    prover_key: "aac_vnet_provekit.pkp",
    verifier_key: "aac_vnet_provekit.pkv",
    proof: "proof.np",
    timeout_ms: 300_000,
  },
});
assert.equal(receipt.accepted, true);
assert.equal(receipt.proof_system, "provekit-whir");
assert.equal(receipt.mode, "native-cli");
assert.match(receipt.proof_digest, /^0x[0-9a-f]{64}$/);
assert.match(receipt.verifier_key_digest, /^0x[0-9a-f]{64}$/);
assert.ok(receipt.timings_ms.prepare >= 0);
assert.ok(receipt.timings_ms.prove >= 0);
assert.ok(receipt.timings_ms.verify >= 0);
assert.equal(adapter.verifyProveKitVerifierReceipt(receipt, { packet }).accepted, true);

const policy = workflow.createWorkflowPolicy({ require_live_proof: true });
const auth = workflow.authorizeFundraiseWorkflow({ packet, verifier_receipt: receipt, policy });
assert.equal(auth.accepted, true);
assert.equal(auth.settlement_action.args.auth.issued_unit_total, 150);
console.log(`native CLI ProveKit receipt accepted; proof=${receipt.proof_digest.slice(0, 18)} vk=${receipt.verifier_key_digest.slice(0, 18)}`);
JS
}

check_real_cli_reject() {
  cp "$RUN_PKG/proof.np" "$RUN_PKG/proof-bad.np"
  printf 'bad-proof-trailer' >> "$RUN_PKG/proof-bad.np"
  HOME="$WORK/home" AAC_CAND_DIR="$CAND_DIR" AAC_RUN_PKG="$RUN_PKG" PROVEKIT_BIN="$PROVEKIT_BIN" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const runPkg = process.env.AAC_RUN_PKG;
const provekitBin = process.env.PROVEKIT_BIN;
const adapter = await import(pathToFileURL(`${cand}/cargo/fundraise-provekit-adapter/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;

await assert.rejects(
  () => adapter.runProveKitNativeCli({
    public_inputs: packet.public_inputs,
    provekit_bin: provekitBin,
    circuit_dir: runPkg,
    cwd: runPkg,
    prover_toml: "Prover.toml",
    verifier_key: "aac_vnet_provekit.pkv",
    proof: "proof-bad.np",
    prepare: false,
    prove: false,
    verify: true,
    timeout_ms: 300_000,
  }),
  (err) => err.reason === "provekit_cli_verify_failed",
);
console.log("native CLI adapter rejects corrupted proof during real ProveKit verify");
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
run 01-structure check_structure      || fail=1
run 02-scope     check_scope          || fail=1
run 03-toolchain resolve_toolchain    || fail=1
run 04-unit      check_unit           || fail=1
run 05-prepare   prepare_workdir      || fail=1
if [[ "$fail" -eq 0 ]]; then
  run 06-real-cli check_real_cli_receipt || fail=1
  run 07-reject   check_real_cli_reject  || fail=1
fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0053-provekit-cli-adapter",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Wire the Nix-packaged native ProveKit CLI path into the fundraise verifier receipt adapter.",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n' "$(grep -q 'adapter exposes native CLI' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'adapter package only' "$TRACES/02-scope.txt" && echo pass || echo fail)"
  printf '    "toolchain": "%s",\n' "$(grep -q 'provekit-cli' "$TRACES/03-toolchain.txt" && echo pass || echo fail)"
  printf '    "unit": "%s",\n' "$(grep -q 'fundraise-provekit-adapter tests: pass' "$TRACES/04-unit.txt" && echo pass || echo fail)"
  printf '    "real_cli_receipt": "%s",\n' "$(grep -q 'native CLI ProveKit receipt accepted' "$TRACES/06-real-cli.txt" && echo pass || echo fail)"
  printf '    "real_cli_reject": "%s"\n' "$(grep -q 'rejects corrupted proof' "$TRACES/07-reject.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
