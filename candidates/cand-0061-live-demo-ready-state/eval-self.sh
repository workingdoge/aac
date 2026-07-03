#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0061-live-demo-ready-state.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-live-ready.XXXXXX)"
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
  mkdir -p "$WORK/web"
  cp "$ROOT/web/package.json" "$WORK/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$WORK/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$WORK/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$WORK/web/scripts"
  cp -R "$ROOT/web/src" "$WORK/web/src"
  cp -R "$ROOT/web/public" "$WORK/web/public"
  ln -s "$ROOT/design" "$WORK/design"
  ln -s "$ROOT/sites" "$WORK/sites"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$WORK/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$WORK/web/node_modules"
  fi
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$WORK/$dst")"
    cp "$CAND_DIR/$src" "$WORK/$dst"
  done < "$CAND_DIR/LANDING"
}

check_source() {
  local comp="$CARGO/web/src/components/aac-fundraise-demo.ts" bad=0
  grep -q "ready-to-run" "$comp" || { echo "missing ready-to-run state"; bad=1; }
  grep -q "ready: no proof run yet" "$comp" || { echo "missing ready note"; bad=1; }
  grep -q "Show capture" "$comp" || { echo "missing explicit capture fallback"; bad=1; }
  grep -q "@click=\${() => this.runLiveProof()}" "$comp" || { echo "live click is not arrow-bound"; bad=1; }
  grep -q "@click=\${() => this.showCapturedReceipt()}" "$comp" || { echo "capture click is not arrow-bound"; bad=1; }
  grep -q "ProveKit not run" "$comp" || { echo "proof lane still appears pre-filled"; bad=1; }
  grep -q "not the default screen" "$CARGO/web/src/content/docs/fundraise.mdx" \
    || { echo "page copy does not state capture is not default"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "source opens ready, arrow-binds actions, and makes capture explicit"
}

check_build() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$WORK/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Private fundraise ready to prove" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "ready headline not bundled"; return 1; }
  grep -rq "Show capture" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "capture control not bundled"; return 1; }
  grep -rq "Run live proof" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "live control not bundled"; return 1; }
  grep -rq "ProveKit not run" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "not-run proof state not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); ready-state controls bundled"
}

check_landing_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is web-only"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-source check_source || fail=1
run 02-build check_build || fail=1
run 03-scope check_landing_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0061-live-demo-ready-state",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Make the fundraise demo open in a ready-to-run state with an explicit captured fallback.",
  "checks": {
    "source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "build": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
