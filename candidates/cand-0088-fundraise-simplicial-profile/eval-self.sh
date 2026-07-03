#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0088-fundraise-simplicial-profile.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
SPEC="$CARGO/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md"
LANDING="$CAND_DIR/LANDING"
WORK="$(mktemp -d /private/tmp/aac-fundraise-simplicial-profile.XXXXXX)"
OVERLAY="$WORK/repo"
OVERLAY_READY=0
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi
WEB_NODE_MODULES="$ROOT/web/node_modules"
if [[ ! -d "$WEB_NODE_MODULES/astro" && -d "/Users/arj/irai/aac/web/node_modules/astro" ]]; then
  WEB_NODE_MODULES="/Users/arj/irai/aac/web/node_modules"
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
  if [[ "$OVERLAY_READY" -eq 1 ]]; then return 0; fi
  mkdir -p "$OVERLAY"
  for dir in design registry; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
  cp -cR "$ROOT/sites" "$OVERLAY/sites" 2>/dev/null \
    || cp -R "$ROOT/sites" "$OVERLAY/sites"
  mkdir -p "$OVERLAY/web"
  cp "$ROOT/web/package.json" "$OVERLAY/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$OVERLAY/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$OVERLAY/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$OVERLAY/web/scripts"
  cp -R "$ROOT/web/src" "$OVERLAY/web/src"
  cp -R "$ROOT/web/public" "$OVERLAY/web/public"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$OVERLAY/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$OVERLAY/web/node_modules"
  fi
  while IFS=$' \t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$LANDING"
  OVERLAY_READY=1
}

check_profile_text() {
  local bad=0
  grep -q '### 2.6 Simplicial statement profile' "$SPEC" \
    || { echo "missing simplicial profile section"; bad=1; }
  grep -q 'FUNDRAISE-CLEARING/1 is a simplicial profile over LEDGER/1 state' "$SPEC" \
    || { echo "missing LEDGER/1 simplicial framing"; bad=1; }
  grep -q 'does not add public ABI slots' "$SPEC" \
    || { echo "profile must state no public ABI expansion"; bad=1; }
  grep -q 'FundraiseVertexSet' "$SPEC" \
    || { echo "missing vertex set"; bad=1; }
  grep -q 'FundraiseEdgeSet' "$SPEC" \
    || { echo "missing edge set"; bad=1; }
  grep -q 'The required 2-simplices are the faces' "$SPEC" \
    || { echo "missing required face language"; bad=1; }
  grep -q 'A face filler is unique up to canonical encoding' "$SPEC" \
    || { echo "missing unique filler rule"; bad=1; }
  grep -q 'horn as `glue_non_contractible`' "$SPEC" \
    || { echo "missing ambiguous horn rejection class"; bad=1; }
  grep -q 'A conformance vector' "$SPEC" \
    || { echo "missing conformance vector guidance"; bad=1; }
  grep -q 'SHOULD be written as a horn plus expected filler' "$SPEC" \
    || { echo "missing horn-shaped conformance guidance"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "simplicial profile defines vertices, edges, horns, fillers, and uniqueness"
}

check_faces() {
  local bad=0
  for face in 'capacity face' 'payment face' 'agreement face' 'transition face' 'VNET face' 'statement face' 'settlement face' 'nullifier face'; do
    grep -q "| $face |" "$SPEC" || { echo "missing $face"; bad=1; }
  done
  grep -q 'transition refs, journal commitments, VNET public vector' "$SPEC" \
    || { echo "VNET face does not bind transition refs and journal commitments"; bad=1; }
  grep -q '`balance_sheet` and `receipt_issuance` statements bound to post-state roots' "$SPEC" \
    || { echo "statement face does not bind post-state roots"; bad=1; }
  grep -q 'settlement action for exactly the token, recipients, issued-unit total, round, and replay domain' "$SPEC" \
    || { echo "settlement face does not bind mint action exactly"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all required fundraise faces are present and bound"
}

check_verifier_and_rejects() {
  local bad=0
  grep -q 'Forms the simplicial horn from the public ABI' "$SPEC" \
    || { echo "verifier does not form horn"; bad=1; }
  grep -q 'Checks that all required simplicial faces fill over the same vertices and edge summaries' "$SPEC" \
    || { echo "verifier does not check all faces over same vertices"; bad=1; }
  grep -q 'A successful proof over one face MUST NOT authorize a settlement action' "$SPEC" \
    || { echo "verifier missing one-face non-authority rule"; bad=1; }
  grep -q 'a simplicial horn whose vertices or edges do not have unique canonical' "$SPEC" \
    || { echo "reject list missing ambiguous horn"; bad=1; }
  grep -q 'any required face filler that is missing, ambiguous, or bound to a different' "$SPEC" \
    || { echo "reject list missing bad filler"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "verifier contract and rejection list enforce horn/filler coherence"
}

check_no_abi_expansion() {
  local rows
  rows="$(grep -E '^\| [0-9]+ \|' "$SPEC" | wc -l | tr -d ' ')"
  [[ "$rows" == "16" ]] || { echo "public ABI row count changed: $rows"; return 1; }
  if grep -qi 'new public input\|new ABI slot\|new registry target\|new circuit\|domain tag' "$SPEC"; then
    grep -ni 'new public input\|new ABI slot\|new registry target\|new circuit\|domain tag' "$SPEC"
    echo "spec appears to add a new public input, target, circuit, or tag"
    return 1
  fi
  echo "simplicial profile preserves the existing 16-slot public ABI and adds no target/circuit/tag"
}

check_landing() {
  local bad=0
  grep -qx 'cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md' "$LANDING" \
    || { echo "missing FUNDRAISE-CLEARING landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$LANDING")" -eq 1 ]] \
    || { echo "LANDING should contain exactly one cargo map"; bad=1; }
  ! grep -q ' tools/' "$LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q ' sites/premath/' "$LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is one fundraise application spec"
}

check_build() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }
  prepare_overlay
  (
    cd "$OVERLAY/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -80 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$OVERLAY/web/dist/specs/applications/fundraise-clearing-1/index.html" ]] \
    || { echo "fundraise clearing spec page not built"; return 1; }
  grep -q 'Simplicial statement profile' "$OVERLAY/web/dist/specs/applications/fundraise-clearing-1/index.html" \
    || { echo "simplicial profile not built into docs"; return 1; }
  echo "astro build OK; simplicial fundraise profile published"
}

run() {
  local nm="$1" fn="$2" rc
  "$fn" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
profile_result=fail
faces_result=fail
verifier_result=fail
abi_result=fail
landing_result=fail
build_result=fail

if run 01-profile check_profile_text; then profile_result=pass; else fail=1; fi
if run 02-faces check_faces; then faces_result=pass; else fail=1; fi
if run 03-verifier check_verifier_and_rejects; then verifier_result=pass; else fail=1; fi
if run 04-abi check_no_abi_expansion; then abi_result=pass; else fail=1; fi
if run 05-landing check_landing; then landing_result=pass; else fail=1; fi
if run 06-build check_build; then build_result=pass; else fail=1; fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0088-fundraise-simplicial-profile",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Define FUNDRAISE-CLEARING/1 as a simplicial statement profile over LEDGER/1 state.",\n'
  printf '  "checks": {\n'
  printf '    "profile": "%s",\n' "$profile_result"
  printf '    "faces": "%s",\n' "$faces_result"
  printf '    "verifier": "%s",\n' "$verifier_result"
  printf '    "abi": "%s",\n' "$abi_result"
  printf '    "landing": "%s",\n' "$landing_result"
  printf '    "build": "%s"\n' "$build_result"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
