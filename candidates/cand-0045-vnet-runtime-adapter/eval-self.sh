#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0045-vnet-runtime-adapter.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
VNET_RUNTIME="$CARGO/vnet-runtime"
BCC_RUNTIME="$CARGO/bcc-runtime"
FUND_RUNTIME="$CARGO/fundraise-runtime"
BCC_SPEC="$CARGO/sites/ledger/specs/applications/BCC-1.md"
FUND_SPEC="$CARGO/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md"
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
  grep -q 'verifyVnetLink' "$VNET_RUNTIME/src/index.mjs" || { echo "vnet runtime missing link verifier"; bad=1; }
  grep -q 'point_not_on_curve' "$VNET_RUNTIME/src/index.mjs" || { echo "vnet runtime missing point checks"; bad=1; }
  grep -q 'verifyVnetLinkReference' "$FUND_RUNTIME/src/index.mjs" || { echo "fundraise runtime missing default vnet verifier"; bad=1; }
  grep -q 'verifyBccCancellation' "$FUND_RUNTIME/src/index.mjs" || { echo "fundraise runtime missing BCC cancellation pass-through"; bad=1; }
  grep -q 'bccCancellationPayload' "$BCC_RUNTIME/src/index.mjs" || { echo "bcc runtime missing cancellation payload"; bad=1; }
  grep -q 'cancellation_verifier_missing' "$BCC_RUNTIME/src/index.mjs" || { echo "bcc runtime missing fail-closed cancellation reason"; bad=1; }
  grep -q 'Cancellation verifier profile' "$BCC_SPEC" || { echo "BCC spec missing cancellation verifier profile"; bad=1; }
  grep -q 'vnet-runtime' "$FUND_SPEC" || { echo "fundraise spec missing vnet-runtime status"; bad=1; }
  grep -q 'bcc-vnet-cancellation-adapter-accept' "$BCC_VECTORS" || { echo "BCC vectors missing cancellation adapter case"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "VNET runtime, fundraise default verifier, and BCC cancellation adapter surfaces are present"
}

check_vnet_runtime() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$VNET_RUNTIME/test/run-tests.mjs"
}

check_bcc_runtime() {
  BCC_VECTOR_PATH="$BCC_VECTORS" "$NODE_BIN" "$BCC_RUNTIME/test/run-tests.mjs"
}

check_fundraise_runtime() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$FUND_RUNTIME/test/run-tests.mjs"
}

check_corrupt() {
  AAC_CAND_DIR="$CAND_DIR" AAC_REPO_ROOT="$ROOT" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const cand = process.env.AAC_CAND_DIR;
const vnet = await import(pathToFileURL(`${cand}/cargo/vnet-runtime/src/index.mjs`));
const bcc = await import(pathToFileURL(`${cand}/cargo/bcc-runtime/src/index.mjs`));
const fund = await import(pathToFileURL(`${cand}/cargo/fundraise-runtime/src/index.mjs`));

const linkFixture = JSON.parse(await readFile(`${process.env.AAC_REPO_ROOT}/sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json`, "utf8"));
const linkGood = linkFixture.vectors.find((vec) => vec.id === "vnet-link-good-fundraise");
const pointBad = structuredClone(linkGood);
pointBad.vnet.atoms[0].debit_commitment.x = "1";
assert.deepEqual(vnet.verifyVnetLink(pointBad), { accepted: false, reason: "non_canonical_point_encoding" });

const bccGood = bcc.demoVectors().vectors.find((vec) => vec.id === "bcc-vnet-cancellation-adapter-accept").certificate;
assert.deepEqual(bcc.verifyBilateralCertificate(bccGood), {
  accepted: false,
  reason: "cancellation_verifier_missing",
});
assert.equal(bcc.verifyBilateralCertificate(bccGood, {
  verifyCancellation: bcc.fixtureVerifyCancellation,
}).accepted, true);
const bccBad = structuredClone(bccGood);
bccBad.cancellation_opening.proof_digest = "bad-proof";
assert.deepEqual(bcc.verifyBilateralCertificate(bccBad, {
  verifyCancellation: bcc.fixtureVerifyCancellation,
}), {
  accepted: false,
  reason: "cancellation_proof_mismatch",
});

const fundFixture = JSON.parse(await readFile(`${process.env.AAC_REPO_ROOT}/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`, "utf8"));
const packet = structuredClone(fundFixture.vectors.find((vec) => vec.id === "fundraise-demo-good").packet);
packet.vnet_link.vnet.atoms[0].debit_commitment.x = "1";
assert.deepEqual(fund.verifyFundraisePacket(packet), {
  accepted: false,
  reason: "vnet_non_canonical_point_encoding",
});

console.log("corrupt VNET point, missing BCC cancellation adapter, and bad cancellation proof were rejected");
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
run 01-text       check_text              || fail=1
run 02-vnet       check_vnet_runtime      || fail=1
run 03-bcc        check_bcc_runtime       || fail=1
run 04-fundraise  check_fundraise_runtime || fail=1
run 05-corrupt    check_corrupt           || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0045-vnet-runtime-adapter",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add JS VNET-BN254/link reference verification, fundraise default VNET verification, and BCC cancellation adapter fail-closed behavior.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'VNET runtime, fundraise default verifier' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "vnet_runtime": "%s",\n' "$(grep -q 'vnet-runtime tests: pass' "$TRACES/02-vnet.txt" && echo pass || echo fail)"
  printf '    "bcc_runtime": "%s",\n' "$(grep -q 'bcc-runtime tests: pass' "$TRACES/03-bcc.txt" && echo pass || echo fail)"
  printf '    "fundraise_runtime": "%s",\n' "$(grep -q 'fundraise-runtime tests: pass' "$TRACES/04-fundraise.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt VNET point' "$TRACES/05-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
