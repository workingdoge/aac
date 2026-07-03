#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0058-fundraise-root-layout-polish.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
WEB="$CARGO/web"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-fundraise-web.XXXXXX)"
rm -rf "$TRACES"; mkdir -p "$TRACES"
WEB_NODE_MODULES="$ROOT/web/node_modules"
if [[ ! -d "$WEB_NODE_MODULES/astro" && -d "/Users/arj/irai/aac/web/node_modules/astro" ]]; then
  WEB_NODE_MODULES="/Users/arj/irai/aac/web/node_modules"
fi

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

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  [[ "$(wc -l < "$CAND_DIR/LANDING" | tr -d ' ')" == "1" ]] || { echo "unexpected landing breadth"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is only aac-fundraise-demo component"
}

check_layout_polish() {
  local comp="$WEB/src/components/aac-fundraise-demo.ts" bad=0
  grep -q ".root-row {" "$comp" || { echo "missing root-row override"; bad=1; }
  grep -q "grid-template-columns: 1fr;" "$comp" || { echo "root-row is not single-column"; bad=1; }
  grep -q "white-space: nowrap;" "$comp" || { echo "root value can still wrap"; bad=1; }
  grep -q "font-size: 11.5px;" "$comp" || { echo "root value size not tightened"; bad=1; }
  grep -q "Seed round settled against private books" "$comp" || { echo "component thesis lost"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "private-root rows keep before/after commitments on one line"
}

prepare_overlay() {
  mkdir -p "$WORK/web"
  cp "$ROOT/web/package.json" "$WORK/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$WORK/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$WORK/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$WORK/web/scripts"
  cp -R "$ROOT/web/src" "$WORK/web/src"
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

check_build() {
  if [[ ! -x "$NODE_BIN" ]]; then echo "SKIP: node absent"; return 0; fi
  if [[ ! -d "$WEB_NODE_MODULES/astro" ]]; then echo "SKIP: web/node_modules absent"; return 0; fi
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  if [[ -z "$PAINT" ]]; then
    local p
    p="$(find /nix/store -maxdepth 4 -path '*/bin/paint' -type f 2>/dev/null | sort | head -1)"
    PAINT="$p"
  fi
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "SKIP: paint absent"; return 0; }
  prepare_overlay
  (
    cd "$WORK/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -20 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  [[ -f "$WORK/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -q 'aac-fundraise-demo' "$WORK/web/dist/fundraise/index.html" || { echo "element not in built page"; return 1; }
  grep -rq "aac-fundraise-demo" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "element not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); /fundraise built, element bundled"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-scope    check_scope          || fail=1
run 02-layout   check_layout_polish  || fail=1
run 03-build    check_build          || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0058-fundraise-root-layout-polish",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Polish /fundraise private-root rows so before/after commitments do not wrap vertically at desktop widths.",\n'
  printf '  "checks": {\n'
  printf '    "scope": "%s",\n' "$(grep -q 'only aac-fundraise-demo' "$TRACES/01-scope.txt" && echo pass || echo fail)"
  printf '    "layout": "%s",\n' "$(grep -q 'one line' "$TRACES/02-layout.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n' "$(grep -qE 'build OK|^SKIP' "$TRACES/03-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
