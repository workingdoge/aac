#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0043-fundraise-bcc-composition.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
RUNTIME="$CARGO/fundraise-runtime"
SPEC="$CARGO/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md"
ORACLE="$CARGO/sites/ledger/specs/applications/reference/fundraise_demo.py"
VECTORS="$CARGO/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json"
VNET_REF="$ROOT/sites/ledger/specs/applications/reference/vnet_link_verifier.py"
PROFILE_REF="$ROOT/sites/ledger/specs/profiles/reference/vnet_bn254_g1_1.py"
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
  grep -q 'BCC/1                 records investor/issuer co-signed agreement certificates' "$SPEC" || { echo "spec missing BCC stack row"; bad=1; }
  grep -q 'BridgeSettlement' "$SPEC" || { echo "spec missing bridge settlement object"; bad=1; }
  grep -q 'bcc_set_commitment' "$SPEC" || { echo "spec missing BCC public input"; bad=1; }
  grep -q 'bridge_settlement_commitment' "$SPEC" || { echo "spec missing bridge public input"; bad=1; }
  grep -q 'buildBccAgreements' "$RUNTIME/src/index.mjs" || { echo "runtime missing buildBccAgreements"; bad=1; }
  grep -q 'verifyBilateralCertificate' "$RUNTIME/src/index.mjs" || { echo "runtime missing BCC verifier"; bad=1; }
  grep -q 'buildBridgeSettlement' "$RUNTIME/src/index.d.ts" || { echo "TS declarations missing bridge builder"; bad=1; }
  grep -q 'fundraise-demo-bcc-signature-reject' "$VECTORS" || { echo "vectors missing BCC signature case"; bad=1; }
  grep -q 'fundraise-demo-bridge-asset-mismatch-reject' "$VECTORS" || { echo "vectors missing bridge asset case"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise text/runtime/vector surface binds BCC agreements and bridge settlement into mint authorization"
}

check_runtime() {
  AAC_REPO_ROOT="$CARGO" "$NODE_BIN" "$RUNTIME/test/run-tests.mjs"
}

check_oracle() {
  PYTHONPYCACHEPREFIX="/tmp/aac-c43-pycache" python3 -m py_compile "$ORACLE"
  python3 "$ORACLE" check "$VECTORS" \
    --vnet-reference "$VNET_REF" \
    --profile-reference "$PROFILE_REF" \
    > "$TRACES/_python_oracle.txt"
  grep -q 'fundraise-demo-bcc-signature-reject: pass accepted=False reason=bcc_signature_mismatch' "$TRACES/_python_oracle.txt"
  grep -q 'fundraise-demo-bridge-asset-mismatch-reject: pass accepted=False reason=bridge_asset_mismatch' "$TRACES/_python_oracle.txt"
}

check_generate() {
  local generated="/tmp/aac-c43-generated-fundraise.json"
  python3 "$ORACLE" generate \
    --vnet-reference "$VNET_REF" \
    --profile-reference "$PROFILE_REF" \
    --out "$generated"
  python3 "$ORACLE" check "$generated" \
    --vnet-reference "$VNET_REF" \
    --profile-reference "$PROFILE_REF" \
    > "$TRACES/_python_generated_check.txt"
  grep -q 'fundraise-demo-good: pass accepted=True reason=accepted' "$TRACES/_python_generated_check.txt"
}

check_corrupt() {
  AAC_REPO_ROOT="$CARGO" "$NODE_BIN" --input-type=module > "$TRACES/_corrupt_runtime.txt" 2>&1 <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyFundraisePacket } from "./candidates/cand-0043-fundraise-bcc-composition/cargo/fundraise-runtime/src/index.mjs";

const fixture = JSON.parse(await readFile("./candidates/cand-0043-fundraise-bcc-composition/cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json", "utf8"));
const good = fixture.vectors.find((v) => v.id === "fundraise-demo-good").packet;

const bccBad = structuredClone(good);
bccBad.bcc_agreements[0].certificate.signatures[0].signature = "corrupt";
assert.deepEqual(verifyFundraisePacket(bccBad), { accepted: false, reason: "bcc_signature_mismatch" });

const bridgeBad = structuredClone(good);
bridgeBad.bridge_settlement.asset_type_id = "EURC:arc-testnet:atomic";
assert.deepEqual(verifyFundraisePacket(bridgeBad), { accepted: false, reason: "bridge_asset_mismatch" });

const digestBad = structuredClone(good);
digestBad.public_inputs.bcc_set_commitment = "bad";
assert.deepEqual(verifyFundraisePacket(digestBad), { accepted: false, reason: "bcc_set_commitment_mismatch" });

console.log("corrupt fundraise BCC/bridge probes rejected signature, bridge asset, and BCC commitment tamper");
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
run 03-oracle   check_oracle   || fail=1
run 04-generate check_generate || fail=1
run 05-corrupt  check_corrupt  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0043-fundraise-bcc-composition",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Bind BCC agreement certificates and bridge settlement context into FUNDRAISE-CLEARING/1 runtime packets and mint authorization.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'fundraise text/runtime/vector surface' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-runtime tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "oracle": "%s",\n' "$(grep -q 'fundraise-demo-bcc-signature-reject: pass' "$TRACES/_python_oracle.txt" && echo pass || echo fail)"
  printf '    "generate": "%s",\n' "$(grep -q 'fundraise-demo-good: pass' "$TRACES/_python_generated_check.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt fundraise BCC/bridge probes rejected' "$TRACES/_corrupt_runtime.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
