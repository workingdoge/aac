#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0079-fundraise-verifier-surface.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-verifier-surface.XXXXXX)"
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
  local runner="$1" types="$2" tests="$3" comp="$4" data="$5" page="$6" bad=0
  grep -q "const verifier = receipt.verifier_receipt" "$runner" \
    || { echo "runner summary does not read verifier receipt"; bad=1; }
  grep -q "verifier:" "$runner" \
    || { echo "runner summary missing verifier object"; bad=1; }
  grep -q "packet_commitment: verifier.packet_commitment" "$runner" \
    || { echo "runner verifier does not expose packet commitment"; bad=1; }
  grep -q "public_inputs_commitment: verifier.public_inputs_commitment" "$runner" \
    || { echo "runner verifier does not expose public-input commitment"; bad=1; }
  grep -q "receipt_digest: verifier.receipt_digest" "$runner" \
    || { echo "runner verifier does not expose receipt digest"; bad=1; }
  grep -q "verifier: {" "$types" \
    || { echo "types missing verifier summary contract"; bad=1; }
  grep -q "summary.verifier.packet_commitment" "$tests" \
    || { echo "runner tests do not assert verifier packet binding"; bad=1; }
  grep -q "summary.verifier.receipt_digest" "$tests" \
    || { echo "runner tests do not assert verifier receipt digest"; bad=1; }
  grep -q "Verifier receipt" "$comp" \
    || { echo "component missing visible verifier receipt lane"; bad=1; }
  grep -q "const verifier = s.verifier" "$comp" \
    || { echo "component does not render summary verifier"; bad=1; }
  grep -q "Verifier accepted proof" "$comp" \
    || { echo "component missing accepted-verifier step"; bad=1; }
  grep -q "Public inputs bound" "$comp" \
    || { echo "component missing public-input binding step"; bad=1; }
  grep -q "Verifier key pinned" "$comp" \
    || { echo "component missing verifier-key step"; bad=1; }
  grep -q "Run proof + verify" "$comp" \
    || { echo "component run control does not name verify"; bad=1; }
  ! grep -q "<b>Clearing proof</b>" "$comp" \
    || { echo "component still hides verifier behind clearing-proof lane"; bad=1; }
  grep -q "packet_commitment: 'b9b42bc" "$data" \
    || { echo "captured summary missing deterministic packet commitment"; bad=1; }
  grep -q "receipt_digest: '0xd4600251" "$data" \
    || { echo "captured summary missing deterministic verifier digest"; bad=1; }
  grep -q "native ProveKit verifier receipt" "$page" \
    || { echo "page copy does not surface verifier receipt"; bad=1; }
  grep -q "recursive on-chain VNET verification" "$page" \
    || { echo "page copy missing on-chain verifier boundary"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise demo exposes a visible native ProveKit verifier receipt"
}

check_source() {
  check_source_file \
    "$CARGO/fundraise-demo-runner/src/index.mjs" \
    "$CARGO/fundraise-demo-runner/src/index.d.ts" \
    "$CARGO/fundraise-demo-runner/test/run-tests.mjs" \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/data/fundraise-demo-summary.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx"
}

check_mutant_rejects_hidden_verifier() {
  local mutant="$WORK/mutant-hidden-verifier.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/Verifier receipt/Clearing proof/g; s/Verifier accepted proof/ProveKit cleared order/g; s/Public inputs bound/Workflow authorized fill/g; s/Run proof \\+ verify/Fill order live/g" "$mutant"
  if check_source_file \
    "$CARGO/fundraise-demo-runner/src/index.mjs" \
    "$CARGO/fundraise-demo-runner/src/index.d.ts" \
    "$CARGO/fundraise-demo-runner/test/run-tests.mjs" \
    "$mutant" \
    "$CARGO/web/src/data/fundraise-demo-summary.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "hidden-verifier mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "hidden-verifier mutant rejected"
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
  grep -rq "Verifier receipt" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verifier receipt lane not bundled"; return 1; }
  grep -rq "native ProveKit verifier accepted" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verifier accepted state not bundled"; return 1; }
  grep -rq "Public inputs bound" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "public-input verifier step not bundled"; return 1; }
  grep -q "native ProveKit verifier receipt" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "fundraise verifier copy not built"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); verifier receipt bundled"
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
  [[ "$bad" -eq 0 ]] && echo "landing scope is runner summary contract + fundraise web verifier surface only"
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
if run 02-mutant check_mutant_rejects_hidden_verifier; then mutant_result=pass; else fail=1; fi
if run 03-runner-tests check_runner_tests; then runner_result=pass; else fail=1; fi
if run 04-build check_build; then build_result=pass; else fail=1; fi
if run 05-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0079-fundraise-verifier-surface",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Expose the native ProveKit verifier receipt in the fundraise summary and render it visibly in the demo.",
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
