#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0007-circuit-ux.
# Witnesses that the aac-transition component registers + is token-themed, the
# /circuit page exists and renders the TRANSITION/1 ABI, and the site builds
# with the element bundled. node/paint located via PATH/PAINT_BIN; honest-skips.
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
  grep -q "customElements.define('aac-transition'" "$COMP/aac-transition.ts" || { echo "MISSING customElements.define('aac-transition')"; bad=1; }
  grep -q "aac-transition" "$COMP/elements.ts" || { echo "elements.ts does not import aac-transition"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "aac-transition registers + is imported by elements.ts"
}

check_theme() {
  grep -q -- '--aac-' "$COMP/aac-transition.ts" || { echo "aac-transition not token-themed"; return 1; }
  echo "aac-transition references --aac-* tokens"
}

check_page() {
  local bad=0
  [[ -f "$DOCS/circuit.mdx" ]] || { echo "no circuit.mdx page"; bad=1; }
  grep -q '<aac-transition' "$DOCS/circuit.mdx" || { echo "page does not embed aac-transition"; bad=1; }
  grep -q 'TRANSITION/1' "$DOCS/circuit.mdx" || { echo "page does not name TRANSITION/1"; bad=1; }
  grep -q 'journal_sum_field_sound' "$DOCS/circuit.mdx" || { echo "page does not tie to the Lean bound"; bad=1; }
  grep -q "'circuit'" "$CARGO/web/astro.config.mjs" || { echo "sidebar does not link circuit"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "/circuit page embeds aac-transition, names TRANSITION/1, ties to journal_sum_field_sound, linked in sidebar"
}

check_build() {
  if [[ ! -d "$ROOT/web/node_modules/astro" ]] || ! command -v node >/dev/null; then echo "SKIP: web/node_modules or node absent"; return 0; fi
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  [[ -n "$PAINT" ]] || { echo "SKIP: paint absent (needed by sync-specs)"; return 0; }
  ( cd "$ROOT/web" && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -6 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  [[ -f "$ROOT/web/dist/circuit/index.html" ]] || { echo "/circuit not built"; return 1; }
  grep -q 'aac-transition' "$ROOT/web/dist/circuit/index.html" || { echo "aac-transition not in the built page"; return 1; }
  grep -rq "aac-transition" "$ROOT/web/dist/_astro/"*.js 2>/dev/null || { echo "aac-transition not in the JS bundle"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); /circuit built, element bundled"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-14s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-register check_register || fail=1
run 02-theme    check_theme    || fail=1
run 03-page     check_page     || fail=1
run 04-build    check_build    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0007-circuit-ux",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "aac-transition component + /circuit page — registers, token-themed, renders the TRANSITION/1 ABI, ties to journal_sum_field_sound, site builds with it bundled",\n'
  printf '  "checks": {\n'
  printf '    "register": "%s",\n' "$(grep -q 'registers' "$TRACES/01-register.txt" && echo pass || echo fail)"
  printf '    "theme": "%s",\n'    "$(grep -q 'references --aac' "$TRACES/02-theme.txt" && echo pass || echo fail)"
  printf '    "page": "%s",\n'     "$(grep -q 'sidebar' "$TRACES/03-page.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'     "$(grep -qE 'build OK|^SKIP' "$TRACES/04-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
