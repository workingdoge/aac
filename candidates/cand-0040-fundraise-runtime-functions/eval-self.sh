#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0040-fundraise-runtime-functions.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/fundraise-runtime"
TRACES="$CAND_DIR/traces"
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
  grep -q 'export function createRoundPolicy' "$CARGO/src/index.mjs" || { echo "missing createRoundPolicy"; bad=1; }
  grep -q 'export function buildFundraisePacket' "$CARGO/src/index.mjs" || { echo "missing buildFundraisePacket"; bad=1; }
  grep -q 'export function verifyFundraisePacket' "$CARGO/src/index.mjs" || { echo "missing verifyFundraisePacket"; bad=1; }
  grep -q 'export function authorizeMint' "$CARGO/src/index.mjs" || { echo "missing authorizeMint"; bad=1; }
  grep -q 'export declare function buildFundraisePacket' "$CARGO/src/index.d.ts" || { echo "missing TS declaration"; bad=1; }
  grep -q 'fixture and audit receipt, not the core runtime' "$CARGO/README.md" || { echo "README missing transcript boundary"; bad=1; }
  grep -q 'reference oracle' "$CARGO/README.md" || { echo "README missing Python oracle boundary"; bad=1; }
  ! grep -q 'python' "$CARGO/src/index.mjs" || { echo "runtime imports or names python"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runtime exposes function-first JS API, TS declarations, transcript boundary, and no Python backend dependency"
}

check_runtime() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" "$CARGO/test/run-tests.mjs"
}

check_oracle_fixture() {
  python3 "$ROOT/sites/ledger/specs/applications/reference/fundraise_demo.py" \
    check "$ROOT/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json" \
    > "$TRACES/_python_oracle.txt"
  grep -q 'fundraise-demo-good: pass accepted=True reason=accepted' "$TRACES/_python_oracle.txt"
}

check_corrupt() {
  AAC_REPO_ROOT="$ROOT" "$NODE_BIN" --input-type=module > "$TRACES/_corrupt_runtime.txt" 2>&1 <<'JS'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { verifyFundraisePacket } from "./candidates/cand-0040-fundraise-runtime-functions/cargo/fundraise-runtime/src/index.mjs";

const fixture = JSON.parse(await readFile("./sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json", "utf8"));
const good = fixture.vectors.find((v) => v.id === "fundraise-demo-good").packet;
const bad = structuredClone(good);
bad.settlement_report.accepted[0].amount += 1;
assert.deepEqual(verifyFundraisePacket(bad), { accepted: false, reason: "settlement_amount_mismatch" });
console.log("corrupt runtime fixture rejected settlement_amount_mismatch");
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
run 01-text    check_text           || fail=1
run 02-runtime check_runtime        || fail=1
run 03-oracle  check_oracle_fixture || fail=1
run 04-corrupt check_corrupt        || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0040-fundraise-runtime-functions",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a function-first JavaScript/TypeScript-facing fundraising runtime; JSON transcript is fixture/audit receipt; Python is reference oracle only.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'function-first JS API' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "runtime": "%s",\n' "$(grep -q 'fundraise-runtime tests: pass' "$TRACES/02-runtime.txt" && echo pass || echo fail)"
  printf '    "oracle": "%s",\n' "$(grep -q 'fundraise-demo-good: pass' "$TRACES/_python_oracle.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'corrupt runtime fixture rejected' "$TRACES/_corrupt_runtime.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
