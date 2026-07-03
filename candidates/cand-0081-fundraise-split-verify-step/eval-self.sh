#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0081-fundraise-split-verify-step.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-split-verify-step.XXXXXX)"
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
  mkdir -p "$OVERLAY/web"
  ln -s "$ROOT/sites" "$OVERLAY/sites"
  ln -s "$ROOT/design" "$OVERLAY/design"
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
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$CAND_DIR/LANDING"
  OVERLAY_READY=1
}

check_source_file() {
  local comp="$1" page="$2" bad=0
  grep -q "type RunState = 'idle' | 'proving' | 'proof-ready' | 'verified' | 'error'" "$comp" \
    || { echo "component lacks split proof/verified states"; bad=1; }
  grep -q "this.ownedButton('verify-proof', 'fundraise-verify', 'verify')" "$comp" \
    || { echo "component does not create a verify control"; bad=1; }
  grep -q "<slot name=\"fundraise-verify\"></slot>" "$comp" \
    || { echo "component does not render the verify slot"; bad=1; }
  grep -q "this.runState = revealVerifier ? 'verified' : 'proof-ready'" "$comp" \
    || { echo "proof run does not stop before visible verification"; bad=1; }
  grep -q "void this.runLiveProof({ revealVerifier: true })" "$comp" \
    || { echo "verify URL fallback does not reveal verifier after proof"; bad=1; }
  grep -q "private canVerifyProof()" "$comp" \
    || { echo "verify control lacks proof-ready guard"; bad=1; }
  grep -q "private verifyProof()" "$comp" \
    || { echo "component lacks explicit verify action"; bad=1; }
  grep -q "verifierVisible ? 'Verifier receipt' : 'Proof packet'" "$comp" \
    || { echo "center lane does not switch proof packet -> verifier receipt"; bad=1; }
  grep -q "if (accepted && !verifierVisible) return 'verify proof'" "$comp" \
    || { echo "book reconciliation does not wait for verifier step"; bad=1; }
  grep -q "Verifier step pending." "$comp" \
    || { echo "component lacks verifier-pending reconciliation message"; bad=1; }
  grep -q "Generate proof" "$comp" \
    || { echo "component lacks generate-proof control text"; bad=1; }
  grep -q "Verify proof" "$comp" \
    || { echo "component lacks verify-proof control text"; bad=1; }
  ! grep -q "Run proof \\+ verify" "$comp" \
    || { echo "component still collapses proof and verifier control"; bad=1; }
  ! grep -q "Proving \\+ verifying" "$comp" \
    || { echo "component still labels proof generation as proof+verify"; bad=1; }
  grep -q "leaves the verifier as" "$page" \
    || { echo "page copy does not name verifier as second step"; bad=1; }
  grep -q "localhost runner returns the proof and verifier receipt" "$page" \
    && grep -q "in one response" "$page" \
    || { echo "page copy does not declare the runner boundary"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise UI separates proof generation from visible verifier acceptance"
}

check_source() {
  check_source_file \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx"
}

check_mutant_rejects_collapsed_verify() {
  local mutant="$WORK/mutant-collapsed-verify.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/this\\.runState = revealVerifier \\? 'verified' : 'proof-ready'/this.runState = 'verified'/; s/Run proof \\+ verify/Generate proof/g" "$mutant"
  if check_source_file "$mutant" "$CARGO/web/src/content/docs/fundraise.mdx" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "collapsed-verifier mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "collapsed-verifier mutant rejected"
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
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$OVERLAY/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Generate proof" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "generate-proof control not bundled"; return 1; }
  grep -rq "Verify proof" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verify-proof control not bundled"; return 1; }
  grep -rq "Proof packet" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "proof-packet lane not bundled"; return 1; }
  grep -rq "Verifier step pending" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verifier-pending state not bundled"; return 1; }
  grep -q "leaves the verifier as" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "fundraise page copy not built"; return 1; }
  echo "astro build OK; split verifier step bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 2 ]] || { echo "landing should be exactly two files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is fundraise web component + page copy only"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
source_result=fail
mutant_result=fail
build_result=fail
scope_result=fail

if run 01-source check_source; then source_result=pass; else fail=1; fi
if run 02-mutant check_mutant_rejects_collapsed_verify; then mutant_result=pass; else fail=1; fi
if run 03-build check_build; then build_result=pass; else fail=1; fi
if run 04-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0081-fundraise-split-verify-step",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Separate proof generation from visible verifier acceptance in the fundraise demo UI.",
  "checks": {
    "source": "$source_result",
    "mutant": "$mutant_result",
    "build": "$build_result",
    "scope": "$scope_result"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
