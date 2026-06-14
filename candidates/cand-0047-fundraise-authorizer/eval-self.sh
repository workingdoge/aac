#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0047-fundraise-authorizer.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
AUTHORIZER="$CARGO/fundraise-authorizer"
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
  grep -q 'authorizeFundraisePacket' "$AUTHORIZER/src/index.mjs" || { echo "missing authorizer entrypoint"; bad=1; }
  grep -q 'buildSettlementSigningRequest' "$AUTHORIZER/src/index.mjs" || { echo "missing signing request builder"; bad=1; }
  grep -q 'verifyFundraisePacket' "$AUTHORIZER/src/index.mjs" || { echo "missing fundraise packet verifier binding"; bad=1; }
  grep -q 'buildEvmMintAuthorization' "$AUTHORIZER/src/index.mjs" || { echo "missing EVM authorization binding"; bad=1; }
  grep -q 'does not sign Ethereum messages' "$AUTHORIZER/README.md" || { echo "README overclaims signing"; bad=1; }
  grep -q 'verify ProveKit proofs' "$AUTHORIZER/README.md" || { echo "README missing ProveKit boundary"; bad=1; }
  grep -q 'fundraise-authorizer' "$SPEC" || { echo "spec missing authorizer status"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "authorizer seam, signing request, runtime verifier binding, and proof/signing boundary text are present"
}

check_runtime() {
  "$NODE_BIN" "$AUTHORIZER/test/run-tests.mjs"
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const authorizer = await import(pathToFileURL(`${cand}/cargo/fundraise-authorizer/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = fixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet;
const receipt = authorizer.authorizeFundraisePacket({ packet });
assert.equal(receipt.accepted, true);

const stale = structuredClone(packet);
stale.public_inputs.issued_unit_total += 1;
assert.deepEqual(authorizer.authorizeFundraisePacket({ packet: stale }).accepted, false);

const badRecipient = authorizer.authorizeFundraisePacket({
  packet,
  recipient_overrides: { "investor-b": "0xnot-an-address" },
});
assert.equal(badRecipient.reason, "bad_mint_recipient");

const tampered = structuredClone(receipt);
tampered.request.contract_authorization.recipients[0].amount += 1;
assert.deepEqual(authorizer.verifyAuthorizerReceipt(tampered), {
  accepted: false,
  reason: "receipt_digest_mismatch",
});
console.log("authorizer rejects stale packets, bad recipients, and tampered receipts");
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
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0047-fundraise-authorizer",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a dependency-free fundraise authorizer seam that verifies packets, binds EVM mint authorization, and emits deterministic settlement signing requests/receipts.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'authorizer seam, signing request' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-authorizer tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'authorizer rejects stale packets' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
