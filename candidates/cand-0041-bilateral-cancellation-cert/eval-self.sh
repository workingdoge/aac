#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0041-bilateral-cancellation-cert.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
RUNTIME="$CAND_DIR/cargo/bcc-runtime"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/BCC-1.md"
INDEX="$CAND_DIR/cargo/sites/ledger/specs/applications/README.md"
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
  grep -q 'Pedersen nets the books' "$SPEC" || { echo "spec missing role-separation phrase"; bad=1; }
  grep -q 'DH is not global finality' "$SPEC" || { echo "spec overclaims DH finality"; bad=1; }
  grep -q 'append-only log, nullifier set, settlement' "$SPEC" || { echo "spec missing finality surface"; bad=1; }
  grep -q 'BCC/1' "$INDEX" || { echo "application index missing BCC/1"; bad=1; }
  grep -q 'export function buildBilateralCertificate' "$RUNTIME/src/index.mjs" || { echo "runtime missing build function"; bad=1; }
  grep -q 'export function verifyBilateralCertificate' "$RUNTIME/src/index.mjs" || { echo "runtime missing verify function"; bad=1; }
  grep -q 'export function createDhEdge' "$RUNTIME/src/index.mjs" || { echo "runtime missing DH edge function"; bad=1; }
  grep -q 'export declare function verifyBilateralCertificate' "$RUNTIME/src/index.d.ts" || { echo "runtime missing TS declaration"; bad=1; }
  grep -q 'mock seams are explicit' "$RUNTIME/README.md" || { echo "runtime README missing mock boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "BCC spec/runtime carry Pedersen/signature/DH/finality split, JS API, TS declarations, and mock-boundary honesty"
}

check_runtime() {
  BCC_VECTOR_PATH="$VECTORS" AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$RUNTIME/test/run-tests.mjs"
}

check_vectors() {
  BCC_VECTOR_PATH="$VECTORS" "$NODE_BIN" --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyBilateralCertificate } from "./candidates/cand-0041-bilateral-cancellation-cert/cargo/bcc-runtime/src/index.mjs";

const doc = JSON.parse(await readFile(process.env.BCC_VECTOR_PATH, "utf8"));
for (const vector of doc.vectors) {
  const ctx = vector.verifier_context ?? {};
  const result = verifyBilateralCertificate(vector.certificate, {
    seen_finality_tags: ctx.seen_finality_tags ?? [],
  });
  assert.equal(result.accepted, vector.expect.accepted, vector.id);
  assert.equal(result.reason, vector.expect.reason, vector.id);
  console.log(`${vector.id}: pass accepted=${result.accepted} reason=${result.reason}`);
}
JS
}

check_corrupt() {
  BCC_VECTOR_PATH="$VECTORS" "$NODE_BIN" --input-type=module > "$TRACES/_corrupt_check.txt" 2>&1 <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyBilateralCertificate } from "./candidates/cand-0041-bilateral-cancellation-cert/cargo/bcc-runtime/src/index.mjs";

const doc = JSON.parse(await readFile(process.env.BCC_VECTOR_PATH, "utf8"));
const good = structuredClone(doc.vectors.find((v) => v.id === "bcc-good-goods-for-cash").certificate);
good.signatures[1].signature = "corrupt";
assert.deepEqual(verifyBilateralCertificate(good), { accepted: false, reason: "signature_mismatch" });
console.log("corrupt BCC signature rejected signature_mismatch");
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
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0041-bilateral-cancellation-cert",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add BCC/1 bilateral cancellation certificate spec, vectors, and JS runtime: two signed opposite committed records, VNET-style cancellation, optional DH edge material, and replay/finality tag checks.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'BCC spec/runtime carry' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'bcc-runtime tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "vectors": "%s",\n' "$(grep -q 'bcc-finality-replay-reject: pass' "$TRACES/03-vectors.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt BCC signature rejected' "$TRACES/_corrupt_check.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
