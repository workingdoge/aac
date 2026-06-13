#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0020-registry-ux.
# Witnesses that aac-row registers + is token-themed, the /registry page embeds
# it and states the 4/REG update rule, and the site builds with it bundled.
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
  grep -q "customElements.define('aac-row'" "$COMP/aac-row.ts" || { echo "MISSING customElements.define('aac-row')"; bad=1; }
  grep -q "aac-row" "$COMP/elements.ts" || { echo "elements.ts does not import aac-row"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "aac-row registers + is imported by elements.ts"
}

check_theme() {
  grep -q -- '--aac-' "$COMP/aac-row.ts" || { echo "aac-row not token-themed"; return 1; }
  # the registry's load-bearing idea: it refuses what it cannot verify + old-root equality
  grep -qi 'refuses' "$COMP/aac-row.ts" && grep -qi 'old-root' "$COMP/aac-row.ts" || { echo "aac-row does not state the trust model"; return 1; }
  echo "aac-row references --aac-* tokens and states the refusal/old-root trust model"
}

check_page() {
  local bad=0
  [[ -f "$DOCS/registry.mdx" ]] || { echo "no registry.mdx page"; bad=1; }
  grep -q '<aac-row' "$DOCS/registry.mdx" || { echo "page does not embed aac-row"; bad=1; }
  grep -q '4/REG' "$DOCS/registry.mdx" || { echo "page does not name 4/REG"; bad=1; }
  grep -qi 'update rule' "$DOCS/registry.mdx" || { echo "page does not state the update rule"; bad=1; }
  grep -q "'registry'" "$CARGO/web/astro.config.mjs" || { echo "sidebar does not link registry"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "/registry page embeds aac-row, names 4/REG + the update rule, sidebar-linked"
}

check_build() {
  if [[ ! -d "$ROOT/web/node_modules/astro" ]] || ! command -v node >/dev/null; then echo "SKIP: web/node_modules or node absent"; return 0; fi
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  [[ -n "$PAINT" ]] || { echo "SKIP: paint absent"; return 0; }
  ( cd "$ROOT/web" && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -6 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  [[ -f "$ROOT/web/dist/registry/index.html" ]] || { echo "/registry not built"; return 1; }
  grep -q 'aac-row' "$ROOT/web/dist/registry/index.html" || { echo "aac-row not in the built page"; return 1; }
  grep -rq "aac-row" "$ROOT/web/dist/_astro/"*.js 2>/dev/null || { echo "aac-row not in the JS bundle"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); /registry built, element bundled"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-register check_register || fail=1
run 02-theme    check_theme    || fail=1
run 03-page     check_page     || fail=1
run 04-build    check_build    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0020-registry-ux",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "aac-row component + /registry page — registers, token-themed, renders a 4/REG row advancing from a TRANSITION/1 proof (old-root equality, refusals), site builds with it bundled",\n'
  printf '  "checks": {\n'
  printf '    "register": "%s",\n' "$(grep -q 'registers' "$TRACES/01-register.txt" && echo pass || echo fail)"
  printf '    "theme": "%s",\n'    "$(grep -q 'trust model' "$TRACES/02-theme.txt" && echo pass || echo fail)"
  printf '    "page": "%s",\n'     "$(grep -q 'sidebar-linked' "$TRACES/03-page.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'     "$(grep -qE 'build OK|^SKIP' "$TRACES/04-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
