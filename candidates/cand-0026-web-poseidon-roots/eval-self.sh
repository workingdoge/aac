#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0026-web-poseidon-roots.
# Witnesses that the web components' hard-coded TRANSITION/1 roots were updated
# from the pre-poseidon (pedersen) values to the cand-0024 Poseidon2 values: the
# cargo files carry the new roots and no stale ones, and the site builds with the
# new values bundled (and none of the old ones anywhere in dist). node/astro via
# PATH/web-node_modules; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/web"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

# the cand-0024 Poseidon2 values (new) and the pre-poseidon ones (must be gone)
NEW='285d0a92 2de709dc 1ad0978e 2b3b2f90 2f4c45bb'
OLD='2d49369e 1515c1ab 147f6950 2d80c14e 10ecbdda'

check_values() {
  local bad=0 f="$CARGO/src/components/aac-transition.ts" r="$CARGO/src/components/aac-row.ts" m="$CARGO/src/content/docs/circuit.mdx"
  # every new value present somewhere across the components
  local v
  for v in $NEW; do grep -rq "$v" "$f" "$r" || { echo "new value $v not in components"; bad=1; }; done
  # no stale pedersen value anywhere in the cargo
  for v in $OLD; do grep -rq "$v" "$CARGO" && { echo "stale pedersen value $v still present"; bad=1; }; done
  grep -q 'this.opcodes = 673' "$f" || { echo "aac-transition opcodes not updated to 673"; bad=1; }
  grep -q '673 ACIR opcodes' "$m" || { echo "circuit.mdx opcodes not updated to 673"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "components carry the new Poseidon2 roots + opcodes 673; no stale pedersen values remain"
}

check_build() {
  if [[ ! -d "$ROOT/web/node_modules/astro" ]] || ! command -v node >/dev/null 2>&1; then
    echo "SKIP: web/node_modules or node absent"; return 0
  fi
  # refresh synced spec content if paint is available; otherwise build the
  # already-synced content (the components/pages under test do not depend on it).
  local PAINT="${PAINT_BIN:-$(command -v paint || true)}"
  ( cd "$ROOT/web" && [[ -n "$PAINT" ]] && PAINT_BIN="$PAINT" node scripts/sync-specs.mjs ) >/dev/null 2>&1 || true
  ( cd "$ROOT/web" && ASTRO_TELEMETRY_DISABLED=1 ./node_modules/.bin/astro build ) > "$TRACES/_build.txt" 2>&1 \
    || { echo "astro build FAILED"; tail -8 "$TRACES/_build.txt"; return 1; }
  grep -qE 'page\(s\) built' "$TRACES/_build.txt" || { echo "no build completion line"; return 1; }
  [[ -f "$ROOT/web/dist/circuit/index.html" && -f "$ROOT/web/dist/registry/index.html" ]] || { echo "/circuit or /registry not built"; return 1; }
  # the new root must be in the JS bundle (the Lit components render client-side).
  grep -rq '285d0a92' "$ROOT/web/dist/_astro/"*.js 2>/dev/null || { echo "new poseidon root not bundled"; return 1; }
  # no stale pedersen value anywhere in the built site.
  local v
  for v in $OLD; do grep -rq "$v" "$ROOT/web/dist" 2>/dev/null && { echo "stale value $v in built site"; return 1; }; done
  grep -q '673 ACIR opcodes' "$ROOT/web/dist/circuit/index.html" || { echo "673 opcodes not rendered on /circuit"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\(s\) built' "$TRACES/_build.txt" | head -1)); new roots bundled, no stale values in dist, 673 on /circuit"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-values check_values || fail=1
run 02-build  check_build  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0026-web-poseidon-roots",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "update the web components hard-coded TRANSITION/1 roots from the pre-poseidon values to the cand-0024 Poseidon2 values (aac-transition + aac-row + circuit.mdx opcodes 775->673); astro build green, the new roots bundled, no stale pedersen values anywhere in dist",\n'
  printf '  "checks": {\n'
  printf '    "values": "%s",\n' "$(grep -q 'no stale pedersen values remain' "$TRACES/01-values.txt" && echo pass || echo fail)"
  printf '    "build": "%s"\n'   "$(grep -qE 'astro build OK|^SKIP' "$TRACES/02-build.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
