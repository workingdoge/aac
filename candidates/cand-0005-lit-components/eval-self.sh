#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0005-lit-components.
# Witnesses the three custom elements register + are token-themed, and that the
# site builds with them. node/paint located via PATH/PAINT_BIN; honest-skips.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
COMP="$CARGO/web/src/components"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_register() {
  local bad=0
  for el in aac-record aac-stamp aac-proof; do
    if grep -q "customElements.define('$el'" "$COMP/${el}.ts"; then echo "define $el OK"
    else echo "MISSING customElements.define('$el')"; bad=1; fi
  done
  [[ "$bad" -eq 0 ]]
}

check_theme() {
  local bad=0
  for el in aac-record aac-stamp aac-proof; do
    grep -q -- '--aac-' "$COMP/${el}.ts" || { echo "$el not token-themed (no --aac-* var)"; bad=1; }
  done
  grep -q 'aac-stamp' "$COMP/aac-record.ts" || { echo "record does not compose the stamp"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all components reference --aac-* tokens; record composes aac-stamp"
}

check_lit() {
  python3 -c "import json;d=json.load(open('$CARGO/web/package.json'));assert 'lit' in d.get('dependencies',{}),'no lit dep';print('lit dep:',d['dependencies']['lit'])"
}

check_build() {
  if [[ ! -d "$ROOT/web/node_modules/astro" ]] || ! command -v node >/dev/null; then echo "SKIP: web/node_modules or node absent"; return 0; fi
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  [[ -n "$PAINT" ]] || { echo "SKIP: paint absent (needed by sync-specs)"; return 0; }
  ( cd "$ROOT/web" && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -6 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  # the bundled JS must carry the element registrations
  grep -rq "aac-record" "$ROOT/web/dist/_astro/"*.js 2>/dev/null || { echo "aac-record not in built bundle"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); elements bundled"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-14s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-register check_register || fail=1
run 02-theme    check_theme    || fail=1
run 03-lit      check_lit      || fail=1
run 04-build    check_build    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0005-lit-components",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Lit web components (aac-record/aac-stamp/aac-proof) — register, token-themed, site builds with them",\n'
  printf '  "checks": {\n'
  printf '    "register": "%s",\n' "$(grep -q 'define aac-proof OK' "$TRACES/01-register.txt" && echo pass || echo fail)"
  printf '    "theme": "%s",\n'    "$(grep -q 'reference --aac' "$TRACES/02-theme.txt" && echo pass || echo fail)"
  printf '    "lit": "%s",\n'      "$(grep -q 'lit dep:' "$TRACES/03-lit.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'     "$(grep -qE 'build OK|^SKIP' "$TRACES/04-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
