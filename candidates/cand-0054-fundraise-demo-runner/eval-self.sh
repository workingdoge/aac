#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0054-fundraise-demo-runner.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
WORK="$(mktemp -d /private/tmp/aac-fundraise-demo-runner.XXXXXX)"
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
  grep -q 'runFundraiseDemo' "$RUNNER/src/index.mjs" || { echo "missing demo runner function"; bad=1; }
  grep -q 'buildProveKitVerifierReceiptFromNativeCli' "$RUNNER/src/index.mjs" \
    || { echo "missing native ProveKit adapter binding"; bad=1; }
  grep -q 'require_live_proof: true' "$RUNNER/src/index.mjs" \
    || { echo "missing live-proof workflow policy"; bad=1; }
  grep -q 'FundraiseMintSettlement.settle' "$RUNNER/README.md" \
    || { echo "README missing settlement-action boundary"; bad=1; }
  grep -q 'does not sign' "$RUNNER/README.md" || { echo "README missing signing boundary"; bad=1; }
  grep -q 'filter: (src) => shouldCopyCircuitPath' "$RUNNER/src/index.mjs" \
    || { echo "missing generated-artifact copy filter"; bad=1; }
  grep -q 'aac-fundraise-demo' "$RUNNER/package.json" || { echo "missing package bin"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runner composes packet -> native ProveKit -> live workflow -> settlement action, with explicit signing/deploy boundary"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/package.json\tfundraise-demo-runner/package.json' "$CAND_DIR/LANDING" \
    || { echo "missing package.json landing"; bad=1; }
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
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo-runner package only; evidence fixtures exclude generated target artifacts"
}

check_unit() {
  "$NODE_BIN" "$RUNNER/test/run-tests.mjs"
}

check_cli_help() {
  "$NODE_BIN" "$RUNNER/bin/fundraise-demo.mjs" --help
}

check_real_cli_demo() {
  local out="$WORK/demo-output.json"
  "$NODE_BIN" "$RUNNER/bin/fundraise-demo.mjs" \
    --repo-root "$CARGO" \
    --provekit-bin "$PROVEKIT_BIN" \
    --out "$out"
  AAC_DEMO_OUT="$out" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const receipt = JSON.parse(await readFile(process.env.AAC_DEMO_OUT, "utf8"));
assert.equal(receipt.schema, "aac.fundraise-demo-runner.receipt.v1");
assert.equal(receipt.accepted, true);
assert.equal(receipt.packet_round_id, "aac-seed-2026-001");
assert.equal(receipt.provekit.mode, "native-cli");
assert.equal(receipt.provekit.proof_system, "provekit-whir");
assert.match(receipt.provekit.proof_digest, /^0x[0-9a-f]{64}$/);
assert.match(receipt.provekit.verifier_key_digest, /^0x[0-9a-f]{64}$/);
assert.equal(receipt.verifier_receipt.accepted, true);
assert.equal(receipt.workflow_receipt.accepted, true);
assert.equal(receipt.settlement_action.method, "settle");
assert.equal(receipt.settlement_action.signature_status, "pending");
assert.equal(receipt.settlement_action.args.signature, null);
assert.equal(receipt.settlement_action.args.auth.issued_unit_total, 150);
assert.equal(receipt.settlement_action.args.auth.recipients.length, 2);
assert.equal(receipt.workdir, null);
console.log(`demo runner emitted proof ${receipt.provekit.proof_digest.slice(0, 18)} and settlement action ${receipt.settlement_action.action_digest.slice(0, 18)}`);
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
run 01-structure check_structure     || fail=1
run 02-scope     check_scope         || fail=1
run 03-toolchain resolve_toolchain   || fail=1
run 04-unit      check_unit          || fail=1
run 05-cli-help  check_cli_help      || fail=1
if [[ "$fail" -eq 0 ]]; then
  run 06-real-cli check_real_cli_demo || fail=1
fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0054-fundraise-demo-runner",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a one-command fundraise demo runner that emits a ProveKit live-proof workflow receipt and settlement action.",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n' "$(grep -q 'runner composes packet' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'demo-runner package only' "$TRACES/02-scope.txt" && echo pass || echo fail)"
  printf '    "toolchain": "%s",\n' "$(grep -q 'provekit-cli' "$TRACES/03-toolchain.txt" && echo pass || echo fail)"
  printf '    "unit": "%s",\n' "$(grep -q 'fundraise-demo-runner tests: pass' "$TRACES/04-unit.txt" && echo pass || echo fail)"
  printf '    "cli_help": "%s",\n' "$(grep -q 'Usage: aac-fundraise-demo' "$TRACES/05-cli-help.txt" && echo pass || echo fail)"
  printf '    "real_cli_demo": "%s"\n' "$(grep -q 'demo runner emitted proof' "$TRACES/06-real-cli.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
