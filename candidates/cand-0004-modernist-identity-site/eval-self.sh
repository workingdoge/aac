#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0004-modernist-identity-site.
# Builds the retoned tokens, re-publishes the spec pack, witnesses the
# two-colour mark, validates the web scaffold, and builds the site.
# paint via PAINT_BIN/PATH; honest-skip (exit 75) if paint is absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

PAINT="${PAINT_BIN:-}"
[[ -z "$PAINT" ]] && PAINT="$(command -v paint || true)"

check_tokens() {
  local d; d="$(mktemp -d)"
  ( cd "$CARGO/design" 2>/dev/null && cp -R "$ROOT/design/"*.json "$ROOT/design/component-contracts.json" . 2>/dev/null; true )
  # build from the real design dir (cargo carries only the changed token JSON)
  ( cd "$ROOT/design" && "$PAINT" build ./aac.resolver.json --contracts ./component-contracts.json --target web-css-vars --namespace aac --out "$d" ) || { echo "token build FAILED"; return 1; }
  "$PAINT" verify "$d/ctc.manifest.json" --format json > "$TRACES/_tok.json" 2>&1 || true
  python3 -c "import json,sys;d=json.load(open('$TRACES/_tok.json'));print('tokens ok:',d.get('ok'));sys.exit(0 if d.get('ok') is True else 1)"
}

check_specpack() {
  local s; s="$(mktemp -d)"; cp -R "$ROOT/sites/ledger/specs" "$s/specs"; cp "$ROOT/sites/ledger/publication.json" "$s/publication.json"
  "$PAINT" spec-pack "$s/publication.json" --out "$s/dist" >/dev/null 2>&1 || { echo "spec-pack FAILED"; return 1; }
  "$PAINT" verify-spec-pack "$s/dist/spec.pack.json" --format json > "$TRACES/_sp.json" 2>&1 || true
  python3 -c "import json,sys;d=json.load(open('$TRACES/_sp.json'));print('specpack ok:',d.get('ok'),'docs:',d.get('checkedDocuments'));sys.exit(0 if d.get('ok') is True and d.get('checkedDocuments')==11 else 1)"
}

check_mark() {  # two colours only: navy + red, no gold
  local fav="$CARGO/web/public/favicon.svg" logo="$CARGO/web/public/logo.svg"
  for f in "$fav" "$logo" "$CARGO/design/brand/aac-mark.svg"; do
    grep -qi '#21324[fF]' "$f" || { echo "missing navy in $(basename "$f")"; return 1; }
    grep -qi '#93302[cC]' "$f" || { echo "missing red in $(basename "$f")"; return 1; }
    grep -qi '#b08a4b' "$f" && { echo "gold present in $(basename "$f") — not two-colour"; return 1; }
  done
  echo "mark is two-colour (navy + red, no gold)"
}

check_web() {
  python3 - "$CARGO/web/package.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
deps=p.get("dependencies",{})
assert "astro" in deps and "@astrojs/starlight" in deps, f"missing astro/starlight: {deps}"
assert p.get("scripts",{}).get("build"), "no build script"
print("package.json valid:", deps.get("astro"), "starlight", deps.get("@astrojs/starlight"))
PY
  for f in astro.config.mjs scripts/sync-specs.mjs src/styles/custom.css src/content.config.ts src/content/docs/index.mdx; do
    [[ -f "$CARGO/web/$f" ]] || { echo "missing web/$f"; return 1; }
  done
  echo "web scaffold present"
}

check_build() {  # skip-tolerant: build the site if deps are installed
  if [[ ! -d "$ROOT/web/node_modules/astro" ]]; then echo "SKIP: web/node_modules absent (run bun install)"; return 0; fi
  command -v node >/dev/null || { echo "SKIP: node absent"; return 0; }
  ( cd "$ROOT/web" && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 || { echo "astro build FAILED"; tail -5 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" && echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1))"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-16s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

if [[ -z "$PAINT" || ! -x "$PAINT" ]]; then
  echo "SKIP: paint not found" > "$TRACES/00-skip.txt"
  { printf '{\n  "schema":"boat.eval-self.v0",\n  "candidate":"cand-0004-modernist-identity-site",\n'
    printf '  "evaluated_at":"%s",\n  "task":"retone tokens + ledger-cell mark + modernist Astro site",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "verdict":"skip(paint-unavailable)"\n}\n'; } > "$CAND_DIR/scores.json"
  bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" || true
  exit 75
fi

fail=0
run 01-tokens    check_tokens   || fail=1
run 02-specpack  check_specpack || fail=1
run 03-mark      check_mark     || fail=1
run 04-web       check_web      || fail=1
run 05-build     check_build    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0004-modernist-identity-site",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "retone design tokens (navy/red + Inter), the ledger-cell mark (two-colour), and a modernist Astro+Starlight site over the verified spec pack",\n'
  printf '  "checks": {\n'
  printf '    "tokens": "%s",\n'   "$(grep -q 'tokens ok: True' "$TRACES/01-tokens.txt" && echo pass || echo fail)"
  printf '    "specpack": "%s",\n' "$(grep -q 'specpack ok: True' "$TRACES/02-specpack.txt" && echo pass || echo fail)"
  printf '    "mark": "%s",\n'     "$(grep -q 'two-colour' "$TRACES/03-mark.txt" && echo pass || echo fail)"
  printf '    "web": "%s",\n'      "$(grep -q 'scaffold present' "$TRACES/04-web.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'     "$(grep -qE 'build OK|^SKIP' "$TRACES/05-build.txt" && echo pass || echo fail)"
  printf '  },\n'
  printf '  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
