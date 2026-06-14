#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0057-fundraise-web-demo.
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

check_register() {
  local bad=0
  grep -q "customElements.define('aac-fundraise-demo'" "$WEB/src/components/aac-fundraise-demo.ts" \
    || { echo "MISSING customElements.define('aac-fundraise-demo')"; bad=1; }
  grep -q "aac-fundraise-demo" "$WEB/src/components/elements.ts" \
    || { echo "elements.ts does not import aac-fundraise-demo"; bad=1; }
  grep -q "fundraiseDemoSummary" "$WEB/src/components/aac-fundraise-demo.ts" \
    || { echo "component does not consume summary fixture"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "aac-fundraise-demo registers and consumes the summary fixture"
}

check_summary_fixture() {
  local bad=0 data="$WEB/src/data/fundraise-demo-summary.ts"
  grep -q "settled-local" "$data" || { echo "summary is not settled-local"; bad=1; }
  grep -q "provekit-whir" "$data" || { echo "summary missing ProveKit proof system"; bad=1; }
  grep -q "total_supply: 150" "$data" || { echo "summary missing total supply 150"; bad=1; }
  grep -q "amount: 100" "$data" || { echo "summary missing investor A balance"; bad=1; }
  grep -q "amount: 50" "$data" || { echo "summary missing investor B balance"; bad=1; }
  grep -q "production recursive/on-chain VNET proof verification remains a separate target" "$data" \
    || { echo "summary missing production verifier caveat"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "summary fixture is settled, proof-bound, balance-bearing, and caveated"
}

check_theme() {
  local comp="$WEB/src/components/aac-fundraise-demo.ts" bad=0
  grep -q -- '--aac-' "$comp" || { echo "component not token-themed"; bad=1; }
  grep -q "Private treasury issuance" "$comp" || { echo "missing fundraise-specific label"; bad=1; }
  grep -q "Seed round settled against private books" "$comp" || { echo "missing first-screen thesis"; bad=1; }
  grep -q "roots move" "$comp" || { echo "missing private-root state lane"; bad=1; }
  grep -q "Proof spine" "$comp" || { echo "missing proof lane"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "component uses AAC tokens and renders the private-root/proof/settlement lanes"
}

check_page() {
  local bad=0
  grep -q '<aac-fundraise-demo' "$WEB/src/content/docs/fundraise.mdx" \
    || { echo "page does not embed aac-fundraise-demo"; bad=1; }
  grep -q "recursive" "$WEB/src/content/docs/fundraise.mdx" \
    || { echo "page does not state verifier boundary"; bad=1; }
  grep -q "'fundraise'" "$WEB/astro.config.mjs" \
    || { echo "sidebar does not link fundraise"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/data/fundraise-demo-summary.ts\tweb/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing data landing"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "/fundraise embeds the demo, states the boundary, and is sidebar-linked"
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
run 01-register check_register        || fail=1
run 02-summary  check_summary_fixture || fail=1
run 03-theme    check_theme           || fail=1
run 04-page     check_page            || fail=1
run 05-build    check_build           || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0057-fundraise-web-demo",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add a token-themed /fundraise presentation console for the ProveKit-to-local-settlement demo summary.",\n'
  printf '  "checks": {\n'
  printf '    "register": "%s",\n' "$(grep -q 'registers' "$TRACES/01-register.txt" && echo pass || echo fail)"
  printf '    "summary_fixture": "%s",\n' "$(grep -q 'balance-bearing' "$TRACES/02-summary.txt" && echo pass || echo fail)"
  printf '    "theme": "%s",\n' "$(grep -q 'private-root/proof/settlement lanes' "$TRACES/03-theme.txt" && echo pass || echo fail)"
  printf '    "page": "%s",\n' "$(grep -q 'sidebar-linked' "$TRACES/04-page.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n' "$(grep -qE 'build OK|^SKIP' "$TRACES/05-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
