#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0083-fundraise-balance-sheet-proof.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-balance-sheet-proof.XXXXXX)"
OVERLAY="$WORK/repo"
OVERLAY_READY=0
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi
WEB_NODE_MODULES="$ROOT/web/node_modules"
if [[ ! -d "$WEB_NODE_MODULES/astro" && -d "/Users/arj/irai/aac/web/node_modules/astro" ]]; then
  WEB_NODE_MODULES="/Users/arj/irai/aac/web/node_modules"
fi

head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

paint_bin() {
  if [[ -n "${PAINT_BIN:-}" && -x "${PAINT_BIN:-}" ]]; then
    printf '%s\n' "$PAINT_BIN"; return 0
  fi
  if command -v paint >/dev/null 2>&1; then
    command -v paint; return 0
  fi
  if [[ -x /Users/arj/irai/blackhole/fish-2026-05-16/tools/paintgun/target/release/paint ]]; then
    printf '%s\n' /Users/arj/irai/blackhole/fish-2026-05-16/tools/paintgun/target/release/paint
    return 0
  fi
  find /nix/store -maxdepth 4 -path '*/bin/paint' -type f 2>/dev/null | sort | head -1
}

prepare_overlay() {
  if [[ "$OVERLAY_READY" -eq 1 ]]; then return 0; fi
  mkdir -p "$OVERLAY"
  for dir in bcc-runtime fundraise-runtime fundraise-provekit-adapter fundraise-workflow vnet-runtime sites design registry; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
  if [[ -d "$ROOT/world-app" ]]; then
    cp -cR "$ROOT/world-app" "$OVERLAY/world-app" 2>/dev/null \
      || cp -R "$ROOT/world-app" "$OVERLAY/world-app"
  fi
  cp -R "$ROOT/fundraise-demo-runner" "$OVERLAY/fundraise-demo-runner"
  mkdir -p "$OVERLAY/web"
  cp "$ROOT/web/package.json" "$OVERLAY/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$OVERLAY/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$OVERLAY/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$OVERLAY/web/scripts"
  cp -R "$ROOT/web/src" "$OVERLAY/web/src"
  cp -R "$ROOT/web/public" "$OVERLAY/web/public"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$OVERLAY/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$OVERLAY/web/node_modules"
  fi
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$CAND_DIR/LANDING"
  OVERLAY_READY=1
}

check_source() {
  local runner="$CARGO/fundraise-demo-runner/src/index.mjs"
  local component="$CARGO/web/src/components/aac-fundraise-demo.ts"
  local page="$CARGO/web/src/content/docs/fundraise.mdx"
  local circuit="$CARGO/world-app/provekit-balance-sheet/src/main.nr"
  local bad=0
  grep -q "DEFAULT_BALANCE_SHEET_PROVEKIT_PACKAGE" "$runner" \
    || { echo "runner lacks balance-sheet package default"; bad=1; }
  grep -q "buildBalanceSheetVerifierReceipt" "$runner" \
    || { echo "runner does not run balance-sheet verifier"; bad=1; }
  grep -q "writeFile(resolve(work.circuit_dir, \"Prover.toml\")" "$runner" \
    || { echo "runner does not write dynamic balance-sheet Prover.toml"; bad=1; }
  grep -q "attachFundraiseBalanceSheetRoots" "$runner" \
    || { echo "runner does not attach computed balance-sheet roots"; bad=1; }
  grep -q "fundraise_packet_commitment" "$runner" \
    || { echo "runner does not bind state proof to fundraise packet"; bad=1; }
  grep -q "displayBalanceSheetVerifier" "$component" \
    || { echo "component lacks balance-sheet verifier display"; bad=1; }
  grep -q "Before/after state proof" "$component" \
    || { echo "component does not label state proof separately"; bad=1; }
  grep -q "separate ProveKit receipt for the issuer balance sheet" "$page" \
    || { echo "page copy does not document separate state proof"; bad=1; }
  grep -q "fundraise_packet_commitment: pub Field" "$circuit" \
    || { echo "circuit lacks packet commitment public input"; bad=1; }
  grep -q "selected batch exceeds open capacity" "$circuit" \
    || { echo "circuit lacks overfill rejection"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "source wires separate dynamic balance-sheet proof through runner and UI"
}

check_runner_tests() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$OVERLAY/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) > "$TRACES/runner-tests.txt" 2>&1 || { echo "runner tests FAILED"; tail -80 "$TRACES/runner-tests.txt"; return 1; }
  grep -q "fundraise-demo-runner tests: pass" "$TRACES/runner-tests.txt" \
    || { echo "runner test pass line missing"; return 1; }
  echo "runner tests OK; preview/run summary includes balance-sheet proof"
}

check_balance_circuit() {
  prepare_overlay
  (
    cd "$OVERLAY/world-app/provekit-balance-sheet" &&
      nix run "$ROOT#nargo19" -- test --show-output
  ) > "$TRACES/balance-circuit.txt" 2>&1 || { echo "balance-sheet circuit tests FAILED"; tail -80 "$TRACES/balance-circuit.txt"; return 1; }
  grep -q "accepts_partial_fill" "$TRACES/balance-circuit.txt" \
    || { echo "balance-sheet circuit test output missing partial-fill case"; return 1; }
  echo "balance-sheet Noir tests OK"
}

check_mutant_rejects_stale_state_root() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  local runner="$OVERLAY/fundraise-demo-runner/src/index.mjs"
  local backup="$WORK/index.mjs.good"
  cp "$runner" "$backup"
  perl -0pi -e 's/next\.public_inputs\.next_balance_sheet_root = roots\.public_inputs\.next_balance_sheet_root;/next.public_inputs.next_balance_sheet_root = roots.public_inputs.prev_balance_sheet_root;/' "$runner"
  (
    cd "$OVERLAY/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) > "$TRACES/mutant-output.txt" 2>&1
  local rc=$?
  cp "$backup" "$runner"
  if [[ "$rc" -eq 0 ]]; then
    cat "$TRACES/mutant-output.txt"
    echo "stale-state-root mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "stale-state-root mutant rejected"
}

check_build() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }
  prepare_overlay
  (
    cd "$OVERLAY/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -80 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$OVERLAY/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Before/after state proof" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "state proof card not bundled"; return 1; }
  grep -rq "balance-sheet verifier not run" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "balance-sheet verifier state not bundled"; return 1; }
  grep -q "separate ProveKit balance-sheet verifier" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "balance-sheet proof copy not built"; return 1; }
  echo "astro build OK; balance-sheet proof UI bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing runner d.ts landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/data/fundraise-demo-summary.ts\tweb/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing captured summary landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  grep -qx $'cargo/world-app/provekit-balance-sheet/Nargo.toml\tworld-app/provekit-balance-sheet/Nargo.toml' "$CAND_DIR/LANDING" \
    || { echo "missing balance-sheet Nargo landing"; bad=1; }
  grep -qx $'cargo/world-app/provekit-balance-sheet/Prover.toml.example\tworld-app/provekit-balance-sheet/Prover.toml.example' "$CAND_DIR/LANDING" \
    || { echo "missing balance-sheet Prover example landing"; bad=1; }
  grep -qx $'cargo/world-app/provekit-balance-sheet/README.md\tworld-app/provekit-balance-sheet/README.md' "$CAND_DIR/LANDING" \
    || { echo "missing balance-sheet README landing"; bad=1; }
  grep -qx $'cargo/world-app/provekit-balance-sheet/src/main.nr\tworld-app/provekit-balance-sheet/src/main.nr' "$CAND_DIR/LANDING" \
    || { echo "missing balance-sheet circuit landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 10 ]] || { echo "landing should be exactly ten files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is runner, fundraise page, and new ProveKit app package only"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
source_result=fail
runner_result=fail
circuit_result=fail
mutant_result=fail
build_result=fail
scope_result=fail

if run 01-source check_source; then source_result=pass; else fail=1; fi
if run 02-runner check_runner_tests; then runner_result=pass; else fail=1; fi
if run 03-circuit check_balance_circuit; then circuit_result=pass; else fail=1; fi
if run 04-mutant check_mutant_rejects_stale_state_root; then mutant_result=pass; else fail=1; fi
if run 05-build check_build; then build_result=pass; else fail=1; fi
if run 06-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0083-fundraise-balance-sheet-proof",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Add a separate live ProveKit proof for the fundraise balance sheet before and after the selected batch.",
  "checks": {
    "source": "$source_result",
    "runner": "$runner_result",
    "circuit": "$circuit_result",
    "mutant": "$mutant_result",
    "build": "$build_result",
    "scope": "$scope_result"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
