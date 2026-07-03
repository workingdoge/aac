#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0078-fundraise-summary-driven-ui.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-summary-driven-ui.XXXXXX)"
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
  mkdir -p "$OVERLAY/web"
  cp -R "$ROOT/fundraise-demo-runner" "$OVERLAY/fundraise-demo-runner"
  ln -s "$ROOT/fundraise-provekit-adapter" "$OVERLAY/fundraise-provekit-adapter"
  ln -s "$ROOT/fundraise-workflow" "$OVERLAY/fundraise-workflow"
  ln -s "$ROOT/fundraise-runtime" "$OVERLAY/fundraise-runtime"
  ln -s "$ROOT/sites" "$OVERLAY/sites"
  ln -s "$ROOT/world-app" "$OVERLAY/world-app"
  ln -s "$ROOT/design" "$OVERLAY/design"
  ln -s "$ROOT/registry" "$OVERLAY/registry"
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

check_source_file() {
  local runner="$1" comp="$2" page="$3" bad=0
  grep -q "packet_projection: buildFundraisePacketProjection(packet)" "$runner" \
    || { echo "runner receipt does not carry packet projection"; bad=1; }
  grep -q "subscriptions.map" "$runner" \
    || { echo "runner summary does not derive fills from subscriptions"; bad=1; }
  grep -q "opening_balances" "$runner" \
    || { echo "runner summary missing opening balances"; bad=1; }
  grep -q "reconciliation" "$runner" \
    || { echo "runner summary missing reconciliation rows"; bad=1; }
  grep -q "metrics" "$runner" \
    || { echo "runner summary missing metric rows"; bad=1; }
  grep -q "const metrics = s.metrics" "$comp" \
    || { echo "component does not render summary metrics"; bad=1; }
  grep -q "const order = s.order" "$comp" \
    || { echo "component does not render summary order"; bad=1; }
  grep -q "const fills = s.fills" "$comp" \
    || { echo "component does not render summary fills"; bad=1; }
  grep -q "const openingBalances = s.opening_balances" "$comp" \
    || { echo "component does not render summary opening balances"; bad=1; }
  grep -q "const reconciliation = s.reconciliation" "$comp" \
    || { echo "component does not render summary reconciliation"; bad=1; }
  ! grep -q "private orderFills" "$comp" \
    || { echo "component still owns hard-coded fill rows"; bad=1; }
  ! grep -q "private openingBalances" "$comp" \
    || { echo "component still owns hard-coded opening balances"; bad=1; }
  ! grep -q "private bookRows" "$comp" \
    || { echo "component still owns hard-coded reconciliation rows"; bad=1; }
  ! grep -q "filledCash" "$comp" \
    || { echo "component still computes filled cash"; bad=1; }
  ! grep -q "filledUnits" "$comp" \
    || { echo "component still computes filled units"; bad=1; }
  ! grep -q "openAfter" "$comp" \
    || { echo "component still computes open units"; bad=1; }
  ! grep -q 'Sell ${orderUnits}' "$comp" \
    || { echo "component still builds order headline from constants"; bad=1; }
  ! grep -q "USDC deposited" "$comp" \
    || { echo "component still hard-codes settlement asset copy"; bad=1; }
  grep -q "summary returned by the localhost API" "$page" \
    || { echo "page does not name runner summary as data source"; bad=1; }
  ! grep -q "150 restricted SAFE receipt units" "$page" \
    || { echo "page still hard-codes order size"; bad=1; }
  ! grep -q "10 USDC each" "$page" \
    || { echo "page still hard-codes price"; bad=1; }
  ! grep -q "two investors" "$page" \
    || { echo "page still hard-codes fill count"; bad=1; }
  ! grep -q "1500 USDC collected" "$page" \
    || { echo "page still hard-codes closing cash"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise UI renders packet-derived summary fields instead of local constants"
}

check_source() {
  check_source_file \
    "$CARGO/fundraise-demo-runner/src/index.mjs" \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx"
}

check_mutant_rejects_component_facts() {
  local mutant="$WORK/mutant-hardcoded-component.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  printf '\nprivate orderFills() { return [{ party: "investor-a", cash: 1000, units: 100 }]; }\n' >> "$mutant"
  if check_source_file "$CARGO/fundraise-demo-runner/src/index.mjs" "$mutant" "$CARGO/web/src/content/docs/fundraise.mdx" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "hard-coded component mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "hard-coded component mutant rejected"
}

check_runner_tests() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  "$NODE_BIN" "$OVERLAY/fundraise-demo-runner/test/run-tests.mjs"
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
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$OVERLAY/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "summary returned by the localhost API" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "fundraise page summary-source copy not built"; return 1; }
  grep -rq "No submitted fills in the runner summary" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "summary-driven empty-fill path not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); summary-driven component bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing runner type landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/data/fundraise-demo-summary.ts\tweb/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing captured summary landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 6 ]] || { echo "landing should be exactly six files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is runner summary contract + fundraise web renderer only"
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
mutant_result=fail
runner_result=fail
build_result=fail
scope_result=fail

if run 01-source check_source; then source_result=pass; else fail=1; fi
if run 02-mutant check_mutant_rejects_component_facts; then mutant_result=pass; else fail=1; fi
if run 03-runner-tests check_runner_tests; then runner_result=pass; else fail=1; fi
if run 04-build check_build; then build_result=pass; else fail=1; fi
if run 05-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0078-fundraise-summary-driven-ui",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Render the fundraise demo from runner summary order, fill, opening-balance, and reconciliation fields instead of component constants.",
  "checks": {
    "source": "$source_result",
    "mutant": "$mutant_result",
    "runner_tests": "$runner_result",
    "build": "$build_result",
    "scope": "$scope_result"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
