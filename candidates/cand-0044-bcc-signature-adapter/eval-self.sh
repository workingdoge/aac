#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0044-bcc-signature-adapter.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
BCC_RUNTIME="$CARGO/bcc-runtime"
FUND_RUNTIME="$CARGO/fundraise-runtime"
BCC_SPEC="$CARGO/sites/ledger/specs/applications/BCC-1.md"
BCC_VECTORS="$CARGO/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json"
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
  grep -q 'Noir and proof-stack boundary' "$BCC_SPEC" || { echo "spec missing Noir boundary"; bad=1; }
  grep -q 'BccSignatureTypedData' "$BCC_SPEC" || { echo "spec missing typed-data payload"; bad=1; }
  grep -q 'verifier adapter' "$BCC_SPEC" || { echo "spec missing verifier-adapter fail-closed rule"; bad=1; }
  grep -q 'bccSignatureTypedData' "$BCC_RUNTIME/src/index.mjs" || { echo "runtime missing typed-data builder"; bad=1; }
  grep -q 'fixtureVerifyTypedDataSignature' "$BCC_RUNTIME/src/index.mjs" || { echo "runtime missing fixture adapter"; bad=1; }
  grep -q 'signature_verifier_missing' "$BCC_RUNTIME/src/index.mjs" || { echo "runtime missing fail-closed reason"; bad=1; }
  grep -q 'bcc-eip712-adapter-accept' "$BCC_VECTORS" || { echo "vectors missing adapter acceptance case"; bad=1; }
  grep -q 'verifyBccSignature' "$FUND_RUNTIME/src/index.mjs" || { echo "fundraise runtime missing BCC verifier pass-through"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "signature adapter surface, fail-closed policy, and Noir composition boundary are present"
}

check_bcc_runtime() {
  BCC_VECTOR_PATH="$BCC_VECTORS" "$NODE_BIN" "$BCC_RUNTIME/test/run-tests.mjs"
}

check_fundraise_runtime() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$FUND_RUNTIME/test/run-tests.mjs"
}

check_adapter_policy() {
  AAC_CAND_DIR="$CAND_DIR" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const mod = await import(pathToFileURL(`${cand}/cargo/bcc-runtime/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${cand}/cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json`, "utf8"));

const accepted = fixture.vectors.find((v) => v.id === "bcc-eip712-adapter-accept").certificate;
const missing = fixture.vectors.find((v) => v.id === "bcc-eip712-missing-verifier-reject").certificate;
const badSigner = fixture.vectors.find((v) => v.id === "bcc-eip712-bad-signer-reject").certificate;

const typedData = mod.bccSignatureTypedData(accepted, accepted.signatures[0]);
assert.equal(typedData.schema, "aac.bcc.signature-typed-data.v1");
assert.equal(typedData.kind, "eip712-compatible");
assert.equal(typedData.message.transcriptHash, `0x${accepted.transcript_hash}`);
assert.equal(typedData.message.finalityTag, `0x${accepted.finality.finality_tag}`);

assert.deepEqual(mod.verifyBilateralCertificate(missing), {
  accepted: false,
  reason: "signature_verifier_missing",
});
assert.equal(mod.verifyBilateralCertificate(accepted, {
  verifySignature: mod.fixtureVerifyTypedDataSignature,
}).accepted, true);
assert.deepEqual(mod.verifyBilateralCertificate(badSigner, {
  verifySignature: mod.fixtureVerifyTypedDataSignature,
}), {
  accepted: false,
  reason: "signature_mismatch",
});

console.log("BCC typed-data adapter policy accepts configured signatures and rejects missing/bad adapters");
JS
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" AAC_REPO_ROOT="$ROOT" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const bcc = await import(pathToFileURL(`${cand}/cargo/bcc-runtime/src/index.mjs`));
const fund = await import(pathToFileURL(`${cand}/cargo/fundraise-runtime/src/index.mjs`));
const fixture = JSON.parse(await readFile(`${process.env.AAC_REPO_ROOT}/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const good = fixture.vectors.find((v) => v.id === "fundraise-demo-good").packet;

const eip712Bcc = structuredClone(good);
for (const agreement of eip712Bcc.bcc_agreements) {
  const cert = agreement.certificate;
  cert.signatures = cert.signatures.map((sig) =>
    bcc.fixtureSignTypedData({
      certificate: cert,
      party_id: sig.party_id,
      public_key: sig.public_key,
    }),
  );
}

assert.deepEqual(fund.verifyFundraisePacket(eip712Bcc), {
  accepted: false,
  reason: "bcc_signature_verifier_missing",
});
assert.equal(fund.verifyFundraisePacket(eip712Bcc, {
  verifyBccSignature: bcc.fixtureVerifyTypedDataSignature,
}).accepted, true);

const badSigner = structuredClone(eip712Bcc);
badSigner.bcc_agreements[0].certificate.signatures[0].public_key = "wrong-signer";
assert.deepEqual(fund.verifyFundraisePacket(badSigner, {
  verifyBccSignature: bcc.fixtureVerifyTypedDataSignature,
}), {
  accepted: false,
  reason: "bcc_signature_mismatch",
});

console.log("fundraise runtime fails closed without BCC signature adapter and rejects bad signer metadata");
JS
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-text            check_text              || fail=1
run 02-bcc-runtime     check_bcc_runtime       || fail=1
run 03-fundraise       check_fundraise_runtime || fail=1
run 04-adapter-policy  check_adapter_policy    || fail=1
run 05-corrupt         check_corrupt           || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0044-bcc-signature-adapter",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a BCC signature adapter seam and keep Noir composition explicit through transcript/context commitments.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'signature adapter surface' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "bcc_runtime": "%s",\n' "$(grep -q 'bcc-runtime tests: pass' "$TRACES/02-bcc-runtime.txt" && echo pass || echo fail)"
  printf '    "fundraise_runtime": "%s",\n' "$(grep -q 'fundraise-runtime tests: pass' "$TRACES/03-fundraise.txt" && echo pass || echo fail)"
  printf '    "adapter_policy": "%s",\n' "$(grep -q 'BCC typed-data adapter policy' "$TRACES/04-adapter-policy.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'fundraise runtime fails closed' "$TRACES/05-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
