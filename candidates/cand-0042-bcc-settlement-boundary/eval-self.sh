#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0042-bcc-settlement-boundary.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
RUNTIME="$CAND_DIR/cargo/bcc-runtime"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/BCC-1.md"
VECTORS="$CAND_DIR/cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json"
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
  grep -q 'BCC/1 is not a settlement proof' "$SPEC" || { echo "spec missing settlement-proof boundary"; bad=1; }
  grep -q 'Authenticated ECDH' "$SPEC" || { echo "spec missing authenticated ECDH"; bad=1; }
  grep -q 'Private witness separation' "$SPEC" || { echo "spec missing public/private split"; bad=1; }
  grep -q 'Contracts bridge assets in and out' "$SPEC" || { echo "spec missing bridge boundary"; bad=1; }
  grep -q 'BCC/1   one bilateral commercial edge cancels' "$SPEC" || { echo "spec missing BCC/VNET distinction"; bad=1; }
  grep -q 'buildBilateralPacket' "$RUNTIME/README.md" || { echo "README missing packet API"; bad=1; }
  grep -q 'verifyBilateralPacket' "$RUNTIME/src/index.d.ts" || { echo "TS declarations missing packet verifier"; bad=1; }
  grep -q 'private_witness' "$RUNTIME/src/index.mjs" || { echo "runtime missing private witness split"; bad=1; }
  grep -q 'authenticated_dh' "$VECTORS" || { echo "vectors missing authenticated ECDH material"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "BCC text/runtime surface states agreement-vs-settlement boundary, authenticated ECDH, public/private split, BCC/VNET distinction, and packet API"
}

check_runtime() {
  BCC_VECTOR_PATH="$VECTORS" AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$RUNTIME/test/run-tests.mjs"
}

check_vectors() {
  BCC_VECTOR_PATH="$VECTORS" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  verifyBilateralCertificate,
  verifyBilateralPacket,
} from "./candidates/cand-0042-bcc-settlement-boundary/cargo/bcc-runtime/src/index.mjs";

const doc = JSON.parse(await readFile(process.env.BCC_VECTOR_PATH, "utf8"));
for (const vector of doc.vectors) {
  const ctx = vector.verifier_context ?? {};
  const result = verifyBilateralCertificate(vector.certificate, {
    seen_finality_tags: ctx.seen_finality_tags ?? [],
  });
  assert.equal(result.accepted, vector.expect.accepted, vector.id);
  assert.equal(result.reason, vector.expect.reason, vector.id);
  if (vector.expect.accepted) {
    assert.equal("debit" in vector.certificate.records[0], false, `${vector.id} public debit leak`);
    assert.equal("credit" in vector.certificate.records[0], false, `${vector.id} public credit leak`);
    const packet = {
      schema: "aac.bcc.packet.v1",
      certificate: vector.certificate,
      private_witness: vector.private_witness,
    };
    assert.equal(verifyBilateralPacket(packet).accepted, true, `${vector.id} packet`);
  }
  console.log(`${vector.id}: pass accepted=${result.accepted} reason=${result.reason}`);
}
JS
}

check_corrupt() {
  "$NODE_BIN" --input-type=module > "$TRACES/_corrupt_check.txt" 2>&1 <<'JS'
import assert from "node:assert/strict";
import {
  demoPacket,
  demoVectors,
  verifyBilateralCertificate,
  verifyBilateralPacket,
} from "./candidates/cand-0042-bcc-settlement-boundary/cargo/bcc-runtime/src/index.mjs";

const packet = demoPacket();
const leak = structuredClone(packet.certificate);
leak.records[0].debit = [3, 0];
assert.equal(verifyBilateralCertificate(leak).reason, "private_witness_leak");

const dh = structuredClone(packet.certificate);
dh.authenticated_dh.public_edge_tag = "corrupt";
assert.equal(verifyBilateralCertificate(dh).reason, "authenticated_dh_mismatch");

const witness = structuredClone(packet);
witness.private_witness.records[0].debit[0] += 1;
assert.equal(verifyBilateralPacket(witness).reason, "record_commitment_mismatch");

const falseNet = demoVectors().vectors.find((v) => v.id === "bcc-cancellation-false-net-reject");
assert.equal(verifyBilateralCertificate(falseNet.certificate).reason, "cancellation_zero_opening");

console.log("corrupt BCC boundary probes rejected private leak, ECDH tamper, witness tamper, and false cancellation");
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
run 03-vectors check_vectors || fail=1
run 04-corrupt check_corrupt || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0042-bcc-settlement-boundary",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Clarify BCC as an agreement certificate with authenticated ECDH and cancellation opening, separating it from private-state settlement proofs and bridge contracts.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'BCC text/runtime surface' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'bcc-runtime tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "vectors": "%s",\n' "$(grep -q 'bcc-private-witness-leak-reject: pass' "$TRACES/03-vectors.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt BCC boundary probes rejected' "$TRACES/_corrupt_check.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
