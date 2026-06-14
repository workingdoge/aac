#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0085-fundraise-persist-verify-result.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-persist-verify-result.XXXXXX)"
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
  cp "$ROOT/web/package.json" "$OVERLAY/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$OVERLAY/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$OVERLAY/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$OVERLAY/web/scripts"
  cp -R "$ROOT/web/src" "$OVERLAY/web/src"
  cp -R "$ROOT/web/public" "$OVERLAY/web/public"
  for dir in sites design; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
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

check_source() {
  local component="${SOURCE_COMPONENT:-$CARGO/web/src/components/aac-fundraise-demo.ts}"
  local bad=0
  grep -q "verifyResult" "$component" \
    || { echo "component lacks verifyResult state"; bad=1; }
  grep -q "renderVerifyResult" "$component" \
    || { echo "component does not re-render verifier result"; bad=1; }
  grep -Fq '<div id="verify-result" aria-live="polite">${this.renderVerifyResult()}</div>' "$component" \
    || { echo "verify-result target does not render persisted state"; bad=1; }
  grep -q "extractVerifyReason" "$component" \
    || { echo "component does not parse htmx verify reason"; bad=1; }
  grep -q "Verifier accepted submitted inputs" "$component" \
    || { echo "component lacks accepted result copy"; bad=1; }
  grep -q "Verifier rejected submitted inputs" "$component" \
    || { echo "component lacks rejected result copy"; bad=1; }
  grep -q "this.verifyResult = null;" "$component" \
    || { echo "component does not reset stale result before new proof"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "source persists htmx verifier result across component re-render"
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
  grep -rq "Verifier accepted submitted inputs" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "accepted result not bundled"; return 1; }
  grep -rq "Verifier rejected submitted inputs" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "rejected result not bundled"; return 1; }
  echo "astro build OK; persistent verifier result bundled"
}

check_mutant_rejects_transient_result() {
  prepare_overlay
  local component="$OVERLAY/web/src/components/aac-fundraise-demo.ts"
  local backup="$WORK/aac-fundraise-demo.ts.good"
  cp "$component" "$backup"
  perl -0pi -e 's/\$\{this\.renderVerifyResult\(\)\}//' "$component"
  SOURCE_COMPONENT="$component" check_source > "$TRACES/mutant-output.txt" 2>&1
  local rc=$?
  cp "$backup" "$component"
  if [[ "$rc" -eq 0 ]]; then
    cat "$TRACES/mutant-output.txt"
    echo "transient-result mutant unexpectedly passed source check"
    return 1
  fi
  grep -q "verify-result target does not render persisted state" "$TRACES/mutant-output.txt" \
    || { cat "$TRACES/mutant-output.txt"; echo "mutant failed for the wrong reason"; return 1; }
  echo "transient-result mutant rejected by source probe"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 1 ]] || { echo "landing should be exactly one file"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is the fundraise component only"
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
build_result=fail
mutant_result=fail
scope_result=fail

if run 01-source check_source; then source_result=pass; else fail=1; fi
if run 02-build check_build; then build_result=pass; else fail=1; fi
if run 03-mutant check_mutant_rejects_transient_result; then mutant_result=pass; else fail=1; fi
if run 04-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0085-fundraise-persist-verify-result",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Preserve htmx verifier form result across Lit re-render.",
  "checks": {
    "source": "$source_result",
    "build": "$build_result",
    "mutant": "$mutant_result",
    "scope": "$scope_result"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
