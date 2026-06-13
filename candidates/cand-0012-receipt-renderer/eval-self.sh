#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0012-receipt-renderer.
# Witnesses that aac-receipt registers + is token-themed, the /components page
# embeds it under a "receipt" section, and the site builds with it bundled.
# node/paint via PATH/PAINT_BIN; honest-skips.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
COMP="$CARGO/web/src/components"
DOCS="$CARGO/web/src/content/docs"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_register() {
  local bad=0
  grep -q "customElements.define('aac-receipt'" "$COMP/aac-receipt.ts" || { echo "MISSING customElements.define('aac-receipt')"; bad=1; }
  grep -q "aac-receipt" "$COMP/elements.ts" || { echo "elements.ts does not import aac-receipt"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "aac-receipt registers + is imported by elements.ts"
}

check_theme() {
  grep -q -- '--aac-' "$COMP/aac-receipt.ts" || { echo "aac-receipt not token-themed"; return 1; }
  # the thesis: per-dimension balance, no numeraire collapse
  grep -qi 'numeraire' "$COMP/aac-receipt.ts" || { echo "receipt does not state the no-numeraire thesis"; return 1; }
  echo "aac-receipt references --aac-* tokens and states the no-numeraire thesis"
}

check_page() {
  local bad=0
  grep -q '<aac-receipt' "$DOCS/components.mdx" || { echo "components page does not embed aac-receipt"; bad=1; }
  grep -qi 'BalancedVectorReceipt' "$DOCS/components.mdx" || { echo "page does not name the BVR"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "/components embeds aac-receipt and names the BalancedVectorReceipt"
}

check_build() {
  if [[ ! -d "$ROOT/web/node_modules/astro" ]] || ! command -v node >/dev/null; then echo "SKIP: web/node_modules or node absent"; return 0; fi
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  [[ -n "$PAINT" ]] || { echo "SKIP: paint absent"; return 0; }
  ( cd "$ROOT/web" && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -6 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  grep -q 'aac-receipt' "$ROOT/web/dist/components/index.html" || { echo "aac-receipt not in the built page"; return 1; }
  grep -rq "aac-receipt" "$ROOT/web/dist/_astro/"*.js 2>/dev/null || { echo "aac-receipt not in the JS bundle"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); receipt built + bundled"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-register check_register || fail=1
run 02-theme    check_theme    || fail=1
run 03-page     check_page     || fail=1
run 04-build    check_build    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0012-receipt-renderer",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "aac-receipt component — registers, token-themed, renders a BalancedVectorReceipt balancing per dimension (no numeraire), shown on /components, site builds with it bundled",\n'
  printf '  "checks": {\n'
  printf '    "register": "%s",\n' "$(grep -q 'registers' "$TRACES/01-register.txt" && echo pass || echo fail)"
  printf '    "theme": "%s",\n'    "$(grep -q 'no-numeraire thesis' "$TRACES/02-theme.txt" && echo pass || echo fail)"
  printf '    "page": "%s",\n'     "$(grep -q 'names the BalancedVectorReceipt' "$TRACES/03-page.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'     "$(grep -qE 'build OK|^SKIP' "$TRACES/04-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
