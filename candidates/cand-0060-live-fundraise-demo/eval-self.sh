#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0060-live-fundraise-demo.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-live-fundraise.XXXXXX)"
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

apply_landing() {
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$WORK/$dst")"
    cp "$CAND_DIR/$src" "$WORK/$dst"
  done < "$CAND_DIR/LANDING"
}

prepare_overlay() {
  cp -R "$ROOT/fundraise-demo-runner" "$WORK/fundraise-demo-runner"
  ln -s "$ROOT/fundraise-provekit-adapter" "$WORK/fundraise-provekit-adapter"
  ln -s "$ROOT/fundraise-workflow" "$WORK/fundraise-workflow"
  ln -s "$ROOT/fundraise-runtime" "$WORK/fundraise-runtime"
  ln -s "$ROOT/fundraise-authorizer" "$WORK/fundraise-authorizer"
  ln -s "$ROOT/world-app" "$WORK/world-app"
  ln -s "$ROOT/sites" "$WORK/sites"
  ln -s "$ROOT/design" "$WORK/design"
  mkdir -p "$WORK/web"
  cp "$ROOT/web/package.json" "$WORK/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$WORK/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$WORK/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$WORK/web/scripts"
  cp -R "$ROOT/web/src" "$WORK/web/src"
  cp -R "$ROOT/web/public" "$WORK/web/public"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$WORK/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$WORK/web/node_modules"
  fi
  apply_landing
}

check_runner_server() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) || return 1
  "$NODE_BIN" --check "$WORK/fundraise-demo-runner/bin/fundraise-demo.mjs" || return 1
  "$NODE_BIN" --check "$WORK/fundraise-demo-runner/src/index.mjs" || return 1
  "$NODE_BIN" "$WORK/fundraise-demo-runner/bin/fundraise-demo.mjs" --help | grep -q -- '--serve' \
    || { echo "CLI help does not expose --serve"; return 1; }
  grep -q "serveFundraiseDemo" "$WORK/fundraise-demo-runner/src/index.d.ts" \
    || { echo "types do not export serveFundraiseDemo"; return 1; }
  grep -q "runFundraiseDemoServerAction" "$WORK/fundraise-demo-runner/src/index.d.ts" \
    || { echo "types do not export runFundraiseDemoServerAction"; return 1; }
  echo "runner unit tests pass; server action, localhost API, and --serve are exposed"
}

check_frontend_source() {
  local comp="$CARGO/web/src/components/aac-fundraise-demo.ts" bad=0
  grep -q "Run live proof" "$comp" || { echo "missing live proof button"; bad=1; }
  grep -q "http://127.0.0.1:8787" "$comp" || { echo "missing localhost API default"; bad=1; }
  grep -q "fetch(this.apiEndpoint()" "$comp" || { echo "component does not fetch live API"; bad=1; }
  grep -q "fundraiseDemoSummary" "$comp" || { echo "component lost captured fallback"; bad=1; }
  grep -q "runner error" "$comp" || { echo "component missing failure state"; bad=1; }
  grep -q "aac-fundraise-demo --serve" "$CARGO/web/src/content/docs/fundraise.mdx" \
    || { echo "fundraise page does not name live runner boundary"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "frontend has live control, fallback summary, and failure boundary"
}

check_web_build() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }
  [[ -d "$WORK/web" ]] || prepare_overlay
  (
    cd "$WORK/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$WORK/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Run live proof" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "live control not bundled"; return 1; }
  grep -rq "127.0.0.1:8787" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "API endpoint not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); live control bundled"
}

check_landing_scope() {
  local bad=0
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  grep -q $'\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" || { echo "missing runner landing"; bad=1; }
  grep -q $'\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" || { echo "missing web component landing"; bad=1; }
  grep -q "requestSettleLocal" "$CARGO/fundraise-demo-runner/src/index.mjs" || { echo "server request mode guard missing"; bad=1; }
  ! grep -q "runFundraiseDemo({ .*\\.\\.\\.body" "$CARGO/fundraise-demo-runner/src/index.mjs" \
    || { echo "browser body can override runner input"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo/web only and request body cannot override runner config"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-runner-server check_runner_server || fail=1
run 02-frontend-source check_frontend_source || fail=1
run 03-web-build check_web_build || fail=1
run 04-landing-scope check_landing_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0060-live-fundraise-demo",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Add a live localhost fundraise demo API and frontend control while preserving the captured receipt fallback.",
  "checks": {
    "runner_server": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "frontend_source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "web_build": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "landing_scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
