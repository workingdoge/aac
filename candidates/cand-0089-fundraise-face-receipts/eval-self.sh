#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0089-fundraise-face-receipts.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-fundraise-face-receipts.XXXXXX)"
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

copy_dir() {
  local src="$1" dst="$2"
  cp -cR "$src" "$dst" 2>/dev/null || cp -R "$src" "$dst"
}

apply_landing_to_overlay() {
  while IFS=$' \t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$CAND_DIR/LANDING"
}

prepare_overlay() {
  if [[ "$OVERLAY_READY" -eq 1 ]]; then return 0; fi
  mkdir -p "$OVERLAY"
  for dir in bcc-runtime vnet-runtime fundraise-authorizer fundraise-provekit-adapter fundraise-workflow world-app registry design sites; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
  copy_dir "$ROOT/fundraise-runtime" "$OVERLAY/fundraise-runtime"
  copy_dir "$ROOT/fundraise-demo-runner" "$OVERLAY/fundraise-demo-runner"
  mkdir -p "$OVERLAY/web"
  cp "$ROOT/web/package.json" "$OVERLAY/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$OVERLAY/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$OVERLAY/web/bun.lock"
  copy_dir "$ROOT/web/scripts" "$OVERLAY/web/scripts"
  copy_dir "$ROOT/web/src" "$OVERLAY/web/src"
  copy_dir "$ROOT/web/public" "$OVERLAY/web/public"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    copy_dir "$WEB_NODE_MODULES" "$OVERLAY/web/node_modules"
  fi
  apply_landing_to_overlay
  OVERLAY_READY=1
}

check_source_shape() {
  local runtime="$CARGO/fundraise-runtime/src/index.mjs"
  local types="$CARGO/fundraise-runtime/src/index.d.ts"
  local runner="$CARGO/fundraise-demo-runner/src/index.mjs"
  local runner_test="$CARGO/fundraise-demo-runner/test/run-tests.mjs"
  local component="$CARGO/web/src/components/aac-fundraise-demo.ts"
  local summary="$CARGO/web/src/data/fundraise-demo-summary.ts"
  local bad=0
  grep -q 'FUNDRAISE_FACE_RECEIPTS_SCHEMA' "$runtime" || { echo "runtime missing face receipt schema"; bad=1; }
  grep -q 'buildFundraiseFaceReceipts' "$runtime" || { echo "runtime missing face receipt builder"; bad=1; }
  grep -q 'fundraiseFaceForReason' "$runtime" || { echo "runtime missing reason-to-face classifier"; bad=1; }
  for face in capacity payment agreement transition vnet statement settlement nullifier; do
    grep -q "\"$face\"" "$runtime" || { echo "runtime missing $face face"; bad=1; }
    grep -q "'$face'" "$summary" || { echo "static summary missing $face face"; bad=1; }
  done
  grep -q 'FundraiseFaceReceipts' "$types" || { echo "types missing face receipts interface"; bad=1; }
  grep -q 'buildFundraiseFaceReceipts' "$runner" || { echo "runner does not import/build face receipts"; bad=1; }
  grep -q 'face_receipts' "$runner" || { echo "runner receipt missing face_receipts"; bad=1; }
  grep -q 'faces:' "$runner" || { echo "runner summary missing faces block"; bad=1; }
  grep -q 'Simplicial face receipts' "$component" || { echo "component does not render face receipts"; bad=1; }
  grep -q 'Array.isArray(faces.items)' "$component" || { echo "component stale-schema guard does not require faces"; bad=1; }
  grep -q 'receipt.summary.faces.items' "$runner_test" || { echo "runner tests do not assert summary faces"; bad=1; }
  grep -q 'native ProveKit statement verifier accepted' "$runner_test" || { echo "runner tests do not pin statement-verifier label"; bad=1; }
  for stale in 'USDC order cap' 'restricted SAFE receipt units in batch' 'Fill 150 of' 'order-fill proof' "'verifier accepted submitted inputs'"; do
    if grep -Rqi "$stale" "$CARGO/fundraise-demo-runner" "$CARGO/web"; then
      echo "stale demo language remains: $stale"
      bad=1
    fi
  done
  if grep -Rq 'const title = accepted ? "Verifier accepted submitted inputs"' "$CARGO/fundraise-demo-runner"; then
    echo "stale verifier result title remains"
    bad=1
  fi
  [[ "$bad" -eq 0 ]] && echo "runtime, runner, and web source expose simplicial face receipts without stale order-fill vocabulary"
}

check_landing() {
  local bad=0
  grep -qx 'cargo/fundraise-runtime/src/index.mjs fundraise-runtime/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise-runtime source landing"; bad=1; }
  grep -qx 'cargo/fundraise-runtime/src/index.d.ts fundraise-runtime/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise-runtime type landing"; bad=1; }
  grep -qx 'cargo/fundraise-runtime/test/run-tests.mjs fundraise-runtime/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise-runtime test landing"; bad=1; }
  grep -qx 'cargo/fundraise-demo-runner/src/index.mjs fundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx 'cargo/fundraise-demo-runner/test/run-tests.mjs fundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx 'cargo/web/src/components/aac-fundraise-demo.ts web/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx 'cargo/web/src/data/fundraise-demo-summary.ts web/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing summary landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 7 ]] \
    || { echo "LANDING should contain exactly seven cargo maps"; bad=1; }
  ! grep -q ' tools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q ' sites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is fundraise runtime, runner, and web demo only"
}

check_package_tests() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  AAC_REPO_ROOT="$OVERLAY" "$NODE_BIN" "$OVERLAY/fundraise-runtime/test/run-tests.mjs" \
    > "$TRACES/runtime-tests.log" 2>&1 || { echo "fundraise-runtime tests FAILED"; cat "$TRACES/runtime-tests.log"; return 1; }
  AAC_REPO_ROOT="$OVERLAY" "$NODE_BIN" "$OVERLAY/fundraise-demo-runner/test/run-tests.mjs" \
    > "$TRACES/runner-tests.log" 2>&1 || { echo "fundraise-demo-runner tests FAILED"; tail -100 "$TRACES/runner-tests.log"; return 1; }
  grep -q 'fundraise-runtime tests: pass' "$TRACES/runtime-tests.log" || { echo "runtime pass marker missing"; return 1; }
  grep -q 'fundraise-demo-runner tests: pass' "$TRACES/runner-tests.log" || { echo "runner pass marker missing"; return 1; }
  echo "fundraise runtime and runner tests pass with face receipts"
}

check_web_build() {
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
  ) > "$TRACES/web-build.log" 2>&1 || { echo "astro build FAILED"; tail -100 "$TRACES/web-build.log"; return 1; }
  grep -q "page(s) built" "$TRACES/web-build.log" || { echo "build completion line missing"; return 1; }
  [[ -f "$OVERLAY/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Simplicial face receipts" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "face receipt panel not bundled"; return 1; }
  grep -rq "Statement verifier inputs" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verifier form not bundled"; return 1; }
  echo "astro build OK; fundraise face receipt panel bundled"
}

check_mutant_rejected() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  perl -0pi -e 's/if \(reason\.startsWith\("vnet_"\)\) return "vnet";/if (reason.startsWith("vnet_")) return "settlement";/' \
    "$OVERLAY/fundraise-runtime/src/index.mjs"
  if AAC_REPO_ROOT="$OVERLAY" "$NODE_BIN" "$OVERLAY/fundraise-runtime/test/run-tests.mjs" \
    > "$TRACES/mutant-vnet-face.log" 2>&1; then
    echo "mutant survived: VNET failures mapped to settlement"
    return 1
  fi
  grep -q 'settlement' "$TRACES/mutant-vnet-face.log" \
    || { echo "mutant failed for an unexpected reason"; tail -80 "$TRACES/mutant-vnet-face.log"; return 1; }
  echo "mutant rejected: VNET failure must map to VNET face"
}

run() {
  local nm="$1" fn="$2" rc
  "$fn" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
source_result=fail
landing_result=fail
package_result=fail
web_result=fail
mutant_result=fail

if run 01-source check_source_shape; then source_result=pass; else fail=1; fi
if run 02-landing check_landing; then landing_result=pass; else fail=1; fi
if run 03-packages check_package_tests; then package_result=pass; else fail=1; fi
if run 04-web-build check_web_build; then web_result=pass; else fail=1; fi
if run 05-mutant check_mutant_rejected; then mutant_result=pass; else fail=1; fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0089-fundraise-face-receipts",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Generate FUNDRAISE-CLEARING/1 simplicial face receipts from the runtime packet and expose them through the demo summary.",\n'
  printf '  "checks": {\n'
  printf '    "source": "%s",\n' "$source_result"
  printf '    "landing": "%s",\n' "$landing_result"
  printf '    "packages": "%s",\n' "$package_result"
  printf '    "web_build": "%s",\n' "$web_result"
  printf '    "mutant": "%s"\n' "$mutant_result"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
