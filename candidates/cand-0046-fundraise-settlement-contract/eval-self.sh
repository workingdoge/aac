#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0046-fundraise-settlement-contract.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
REGISTRY="$CARGO/registry"
FUND_RUNTIME="$CARGO/fundraise-runtime"
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
  grep -q 'contract FundraiseMintSettlement' "$REGISTRY/src/FundraiseSettlement.sol" || { echo "missing settlement contract"; bad=1; }
  grep -Fq 'settled[digest]' "$REGISTRY/src/FundraiseSettlement.sol" || { echo "missing replay mark"; bad=1; }
  grep -q 'ecrecover' "$REGISTRY/src/FundraiseSettlement.sol" || { echo "missing authorizer signature recovery"; bad=1; }
  grep -q 'runtimeAuthorizationDigest' "$REGISTRY/src/FundraiseSettlement.sol" || { echo "missing runtime digest binding"; bad=1; }
  grep -q 'buildEvmMintAuthorization' "$FUND_RUNTIME/src/index.mjs" || { echo "runtime missing EVM auth helper"; bad=1; }
  grep -q 'bad_mint_recipient' "$FUND_RUNTIME/src/index.mjs" || { echo "runtime missing recipient address guard"; bad=1; }
  grep -q 'Demo settlement adapter' "$SPEC" || { echo "spec missing settlement adapter section"; bad=1; }
  grep -q "authorizer/orchestrator's obligation" "$SPEC" || { echo "spec missing proof-boundary honesty"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "settlement contract, runtime EVM helper, replay guard, and proof-boundary text are present"
}

check_runtime() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$FUND_RUNTIME/test/run-tests.mjs"
}

check_solidity() {
  nix --extra-experimental-features 'nix-command flakes' develop -c bash -lc \
    "cd '$REGISTRY' && forge test --use \"\$(command -v solc)\" --match-contract FundraiseSettlementTest"
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" AAC_REPO_ROOT="$ROOT" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const fund = await import(pathToFileURL(`${cand}/cargo/fundraise-runtime/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${process.env.AAC_REPO_ROOT}/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;
const verified = fund.verifyFundraisePacket(packet);
assert.equal(verified.accepted, true);
const auth = verified.authorization;
assert.throws(() => fund.buildEvmMintAuthorization(auth), /bad_token_contract/);
const ready = structuredClone(auth);
ready.recipients[0].recipient = "0x00000000000000000000000000000000000A11CE";
ready.recipients[1].recipient = "0x0000000000000000000000000000000000000B0B";
const evm = fund.buildEvmMintAuthorization(ready, {
  tokenContract: "0xAac0000000000000000000000000000000000039",
});
assert.equal(evm.runtime_authorization_digest, `0x${auth.authorization_digest}`);
assert.equal(evm.issued_unit_total, 150);
ready.recipients[0].recipient = "not-an-address";
assert.throws(() => fund.buildEvmMintAuthorization(ready, {
  tokenContract: "0xAac0000000000000000000000000000000000039",
}), /bad_mint_recipient/);
console.log("EVM mint authorization rejects symbolic token/recipient values and preserves runtime digest binding");
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
run 01-text     check_text     || fail=1
run 02-runtime  check_runtime  || fail=1
run 03-solidity check_solidity || fail=1
run 04-corrupt  check_corrupt  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0046-fundraise-settlement-contract",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add runtime EVM mint authorization shaping and a Solidity settlement adapter that verifies authorizer/round/token/recipient-set/replay before minting.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'settlement contract, runtime EVM helper' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-runtime tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "solidity": "%s",\n' "$(grep -q '8 passed; 0 failed' "$TRACES/03-solidity.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'EVM mint authorization rejects' "$TRACES/04-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
