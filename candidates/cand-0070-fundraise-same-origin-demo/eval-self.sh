#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0070-fundraise-same-origin-demo.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-fundraise-same-origin.XXXXXX)"
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

check_source_file() {
  local runner="$1" types="$2" cli="$3" comp="$4" page="$5" bad=0
  grep -q "static_dir: staticDir" "$runner" || { echo "runner does not pass static_dir into requests"; bad=1; }
  grep -q "writeStaticAsset(response, input.static_dir" "$runner" || { echo "runner does not serve static assets"; bad=1; }
  grep -q "resolveFundraiseStaticPath" "$runner" || { echo "runner missing static path resolver"; bad=1; }
  grep -q "pathInside(root, candidate)" "$runner" || { echo "runner missing traversal guard"; bad=1; }
  grep -q "fundraiseStaticContentType" "$runner" || { echo "runner missing content-type helper"; bad=1; }
  grep -q "static_dir?: string" "$types" || { echo "types missing static_dir"; bad=1; }
  grep -q "resolveFundraiseStaticPath" "$types" || { echo "types missing static resolver"; bad=1; }
  grep -q -- "--static-dir" "$cli" || { echo "CLI missing --static-dir"; bad=1; }
  grep -q "static: \${service.url}/" "$cli" || { echo "CLI does not print static origin"; bad=1; }
  grep -q "private defaultApiBase(): string" "$comp" || { echo "component missing default API base helper"; bad=1; }
  grep -q "window.location.origin" "$comp" || { echo "component does not use same-origin localhost API"; bad=1; }
  grep -q "127.0.0.1:8787" "$comp" || { echo "component lost explicit runner fallback"; bad=1; }
  grep -q "fetch(this.apiRunUrl(), { method: 'GET' })" "$comp" || { echo "component lost simple GET runner call"; bad=1; }
  grep -q "aac-fundraise-demo --serve --static-dir web/dist --port 4328" "$page" \
    || { echo "fundraise page does not document same-origin demo mode"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runner serves static UI, component defaults to same-origin localhost API"
}

check_source() {
  check_source_file \
    "$RUNNER/src/index.mjs" \
    "$RUNNER/src/index.d.ts" \
    "$RUNNER/bin/fundraise-demo.mjs" \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx"
}

check_mutant_rejects_cross_origin_default() {
  local mutant="$WORK/mutant-component.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/\\n  private defaultApiBase\\(\\): string \\{.*?\\n  \\}\\n//s" "$mutant"
  if check_source_file \
    "$RUNNER/src/index.mjs" \
    "$RUNNER/src/index.d.ts" \
    "$RUNNER/bin/fundraise-demo.mjs" \
    "$mutant" \
    "$CARGO/web/src/content/docs/fundraise.mdx" >/tmp/aac-same-origin-mutant.$$ 2>&1; then
    cat /tmp/aac-same-origin-mutant.$$
    rm -f /tmp/aac-same-origin-mutant.$$
    echo "mutant unexpectedly passed"
    return 1
  fi
  cat /tmp/aac-same-origin-mutant.$$
  rm -f /tmp/aac-same-origin-mutant.$$
  echo "cross-origin-default mutant rejected"
}

check_unit() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs &&
      "$NODE_BIN" --check src/index.mjs &&
      "$NODE_BIN" --check bin/fundraise-demo.mjs &&
      "$NODE_BIN" bin/fundraise-demo.mjs --help
  )
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
  grep -rq "window.location.origin" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "same-origin API default not bundled"; return 1; }
  grep -rq "apiRunUrl" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "runner URL helper not bundled"; return 1; }
  grep -rq "method:\"GET\"" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "GET runner fetch not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); same-origin API default bundled"
}

check_landing_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing runner type landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/bin/fundraise-demo.mjs\tfundraise-demo-runner/bin/fundraise-demo.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner CLI landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise page landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 6 ]] || { echo "landing should be runner plus fundraise page/component only"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo runner plus fundraise page/component only"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-source check_source || fail=1
run 02-mutant check_mutant_rejects_cross_origin_default || fail=1
run 03-unit check_unit || fail=1
run 04-web-build check_web_build || fail=1
run 05-scope check_landing_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0070-fundraise-same-origin-demo",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Serve the fundraise UI and live proof API from one localhost origin.",
  "checks": {
    "source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "mutant": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "unit": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "web_build": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
