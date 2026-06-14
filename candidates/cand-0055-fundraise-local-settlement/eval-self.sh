#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0055-fundraise-local-settlement.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
WORK="$(mktemp -d /private/tmp/aac-fundraise-local-settle.XXXXXX)"
rm -rf "$TRACES"; mkdir -p "$TRACES"
rm -rf "$CARGO/registry/cache" "$CARGO/registry/out"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi
PROVEKIT_BIN="${PROVEKIT_BIN:-}"
FORGE_BIN="${FORGE_BIN:-}"
CAST_BIN="${CAST_BIN:-}"
ANVIL_BIN="${ANVIL_BIN:-}"
SOLC_BIN="${SOLC_BIN:-}"

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
  if [[ -z "$FORGE_BIN" || -z "$CAST_BIN" || -z "$ANVIL_BIN" ]]; then
    while IFS= read -r p; do
      case "$p" in
        */bin/forge) [[ -z "$FORGE_BIN" ]] && FORGE_BIN="$p" ;;
        */bin/cast) [[ -z "$CAST_BIN" ]] && CAST_BIN="$p" ;;
        */bin/anvil) [[ -z "$ANVIL_BIN" ]] && ANVIL_BIN="$p" ;;
      esac
    done < <(find /nix/store -maxdepth 5 -path '*/bin/*' -type f 2>/dev/null | sort)
  fi
  if [[ -z "$SOLC_BIN" ]]; then
    while IFS= read -r p; do
      case "$p" in
        */bin/solc) SOLC_BIN="$p"; break ;;
      esac
    done < <(find /nix/store -maxdepth 5 -path '*/bin/solc' -type f 2>/dev/null | sort)
  fi
  [[ -x "$PROVEKIT_BIN" ]] || { echo "provekit-cli binary not found in /nix/store"; return 1; }
  [[ -x "$FORGE_BIN" ]] || { echo "forge binary not found in /nix/store"; return 1; }
  [[ -x "$CAST_BIN" ]] || { echo "cast binary not found in /nix/store"; return 1; }
  [[ -x "$ANVIL_BIN" ]] || { echo "anvil binary not found in /nix/store"; return 1; }
  [[ -x "$SOLC_BIN" ]] || { echo "solc binary not found in /nix/store"; return 1; }
  "$NODE_BIN" --version
  "$PROVEKIT_BIN" --help | head -n 1
  "$FORGE_BIN" --version
  "$CAST_BIN" --version
  "$ANVIL_BIN" --version
  "$SOLC_BIN" --version | head -n 1
}

check_structure() {
  local bad=0
  grep -q 'runFundraiseDemoLocalSettlement' "$RUNNER/src/index.mjs" \
    || { echo "missing local settlement runner"; bad=1; }
  grep -q 'prepareFoundrySettlement' "$RUNNER/src/index.mjs" \
    || { echo "missing Foundry deployment helper"; bad=1; }
  grep -q 'cast wallet sign --no-hash' "$RUNNER/README.md" \
    || { echo "README missing raw digest signing boundary"; bad=1; }
  grep -q -- '--settle-local' "$RUNNER/bin/fundraise-demo.mjs" \
    || { echo "CLI missing settle-local flag"; bad=1; }
  grep -q 'settle((bytes32,address,bytes32,bytes32,uint256,(address,uint256)\[\]),bytes)' "$RUNNER/src/index.mjs" \
    || { echo "missing contract settle call"; bad=1; }
  grep -q 'does not deploy to a public testnet' "$RUNNER/README.md" \
    || { echo "README missing local-only boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runner has local Foundry deploy/sign/settle path with explicit local-only boundary"
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
  ! grep -q $'\tregistry/' "$CAND_DIR/LANDING" || { echo "unexpected registry landing"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  ! find "$CAND_DIR/cargo" -path '*/target/*' -type f | grep -q . \
    || { echo "generated target artifact included"; bad=1; }
  ! find "$CAND_DIR/cargo/registry" \( -path '*/out/*' -o -path '*/cache/*' \) -type f | grep -q . \
    || { echo "generated Foundry artifact included"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo-runner only; registry is evidence fixture without generated artifacts"
}

check_unit() {
  "$NODE_BIN" "$RUNNER/test/run-tests.mjs"
}

check_cli_help() {
  "$NODE_BIN" "$RUNNER/bin/fundraise-demo.mjs" --help
}

check_real_local_settlement() {
  local port rpc out pid
  port=$((18550 + ($$ % 1000)))
  rpc="http://127.0.0.1:$port"
  out="$WORK/local-settlement.json"
  "$ANVIL_BIN" --host 127.0.0.1 --port "$port" > "$TRACES/anvil.txt" 2>&1 &
  pid=$!
  trap 'if [[ -n "${pid:-}" ]]; then kill "$pid" 2>/dev/null || true; fi' RETURN
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    "$CAST_BIN" block-number --rpc-url "$rpc" >/dev/null 2>&1 && break
    sleep 1
  done
  "$CAST_BIN" block-number --rpc-url "$rpc" >/dev/null

  "$NODE_BIN" "$RUNNER/bin/fundraise-demo.mjs" \
    --repo-root "$CARGO" \
    --provekit-bin "$PROVEKIT_BIN" \
    --settle-local \
    --rpc-url "$rpc" \
    --forge-bin "$FORGE_BIN" \
    --cast-bin "$CAST_BIN" \
    --solc-bin "$SOLC_BIN" \
    --out "$out" || return 1

  AAC_LOCAL_SETTLEMENT_OUT="$out" \
  CAST_BIN="$CAST_BIN" \
  RPC_URL="$rpc" \
  DEPLOYER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
  "$NODE_BIN" --input-type=module <<'JS' || return 1
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";

const receipt = JSON.parse(await readFile(process.env.AAC_LOCAL_SETTLEMENT_OUT, "utf8"));
assert.equal(receipt.accepted, true);
assert.equal(receipt.local_settlement.schema, "aac.fundraise-demo-runner.local-settlement.v1");
assert.equal(receipt.local_settlement.total_supply, 150);
assert.deepEqual(receipt.local_settlement.balances.map((item) => item.amount), [100, 50]);
assert.match(receipt.local_settlement.token_contract, /^0x[0-9a-fA-F]{40}$/);
assert.match(receipt.local_settlement.settlement_contract, /^0x[0-9a-fA-F]{40}$/);
assert.match(receipt.local_settlement.transaction_hash, /^0x[0-9a-fA-F]{64}$/);
assert.equal(
  receipt.settlement_action.args.auth.token_contract.toLowerCase(),
  receipt.local_settlement.token_contract.toLowerCase(),
);
assert.equal(receipt.settlement_action.contract.toLowerCase(), receipt.local_settlement.settlement_contract.toLowerCase());

const auth = receipt.settlement_action.args.auth;
const tuple = `(${[
  auth.round_id_hash,
  auth.token_contract,
  auth.runtime_authorization_digest,
  auth.runtime_mint_recipient_set_commitment,
  String(auth.issued_unit_total),
  `[${auth.recipients.map((recipient) => `(${recipient.account},${recipient.amount})`).join(",")}]`,
].join(",")})`;
const replay = spawnSync(process.env.CAST_BIN, [
  "send",
  "--rpc-url",
  process.env.RPC_URL,
  "--private-key",
  process.env.DEPLOYER_PK,
  receipt.local_settlement.settlement_contract,
  "settle((bytes32,address,bytes32,bytes32,uint256,(address,uint256)[]),bytes)",
  tuple,
  receipt.local_settlement.signature,
], { encoding: "utf8" });
assert.notEqual(replay.status, 0);
assert.match(`${replay.stdout}\n${replay.stderr}`, /already settled|execution reverted/);
console.log(`local settlement minted supply ${receipt.local_settlement.total_supply}; replay rejected`);
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
  run 06-local-settle check_real_local_settlement || fail=1
fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0055-fundraise-local-settlement",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add local Foundry deploy/sign/settle submission to the ProveKit fundraise demo runner.",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n' "$(grep -q 'local Foundry deploy/sign/settle' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'demo-runner only' "$TRACES/02-scope.txt" && echo pass || echo fail)"
  printf '    "toolchain": "%s",\n' "$(grep -q 'forge' "$TRACES/03-toolchain.txt" && grep -q 'solc' "$TRACES/03-toolchain.txt" && echo pass || echo fail)"
  printf '    "unit": "%s",\n' "$(grep -q 'fundraise-demo-runner tests: pass' "$TRACES/04-unit.txt" && echo pass || echo fail)"
  printf '    "cli_help": "%s",\n' "$(grep -q -- '--settle-local' "$TRACES/05-cli-help.txt" && echo pass || echo fail)"
  printf '    "local_settlement": "%s"\n' "$(grep -q 'replay rejected' "$TRACES/06-local-settle.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
