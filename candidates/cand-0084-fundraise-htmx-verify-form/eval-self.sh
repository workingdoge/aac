#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0084-fundraise-htmx-verify-form.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-htmx-verify-form.XXXXXX)"
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
  mkdir -p "$OVERLAY"
  for dir in bcc-runtime fundraise-runtime fundraise-provekit-adapter fundraise-workflow vnet-runtime sites design registry world-app; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
  cp -R "$ROOT/fundraise-demo-runner" "$OVERLAY/fundraise-demo-runner"
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
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$CAND_DIR/LANDING"
  OVERLAY_READY=1
}

check_source() {
  local runner="$CARGO/fundraise-demo-runner/src/index.mjs"
  local component="$CARGO/web/src/components/aac-fundraise-demo.ts"
  local adapter="$CARGO/web/src/components/aac-htmx.ts"
  local elements="$CARGO/web/src/components/elements.ts"
  local page="$CARGO/web/src/content/docs/fundraise.mdx"
  local bad=0
  grep -q "runFundraiseDemoProveAction" "$runner" \
    || { echo "runner lacks prove action"; bad=1; }
  grep -q "runFundraiseDemoVerifyAction" "$runner" \
    || { echo "runner lacks verify action"; bad=1; }
  grep -q "submitted_public_input_mismatch" "$runner" \
    || { echo "runner lacks submitted-input mismatch rejection"; bad=1; }
  grep -q "rerunStoredFundraiseVerification" "$runner" \
    || { echo "runner does not rerun ProveKit verify from stored proof artifacts"; bad=1; }
  grep -q "requestWantsHtmlFragment" "$runner" \
    || { echo "runner lacks htmx HTML fragment response"; bad=1; }
  grep -q "hx-post" "$component" \
    || { echo "component lacks htmx form post"; bad=1; }
  grep -q "Verify submitted inputs" "$component" \
    || { echo "component lacks submitted-input verify action"; bad=1; }
  grep -q "Tamper next root" "$component" \
    || { echo "component lacks visible tamper probe"; bad=1; }
  ! grep -q "sourceLabel = 'verifier accepted';" "$component" \
    || { echo "component still reveals verifier acceptance locally"; bad=1; }
  grep -q "form\\[hx-post\\]" "$adapter" \
    || { echo "adapter does not bind hx-post forms"; bad=1; }
  grep -q "hx-request" "$adapter" \
    || { echo "adapter does not send htmx request header"; bad=1; }
  grep -q "htmx:afterRequest" "$adapter" \
    || { echo "adapter lacks htmx lifecycle event"; bad=1; }
  grep -q "import './aac-htmx'" "$elements" \
    || { echo "elements loader does not import htmx adapter"; bad=1; }
  grep -q "/api/fundraise/verify" "$page" \
    || { echo "docs do not describe verify endpoint"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "source wires htmx-submitted verifier form through runner and UI"
}

check_runner_tests() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$OVERLAY/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) > "$TRACES/runner-tests.txt" 2>&1 || { echo "runner tests FAILED"; tail -80 "$TRACES/runner-tests.txt"; return 1; }
  grep -q "fundraise-demo-runner tests: pass" "$TRACES/runner-tests.txt" \
    || { echo "runner test pass line missing"; return 1; }
  echo "runner tests OK; prove session, form verify, and tamper rejection pass"
}

check_mutant_rejects_missing_field_guard() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  local runner="$OVERLAY/fundraise-demo-runner/src/index.mjs"
  local backup="$WORK/index.mjs.good"
  cp "$runner" "$backup"
  perl -0pi -e 's/const mismatches = submittedVerifyFieldMismatches\(body, session\.expected_fields\);/const mismatches = [];/' "$runner"
  (
    cd "$OVERLAY/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) > "$TRACES/mutant-output.txt" 2>&1
  local rc=$?
  cp "$backup" "$runner"
  if [[ "$rc" -eq 0 ]]; then
    cat "$TRACES/mutant-output.txt"
    echo "submitted-field-guard mutant unexpectedly passed"
    return 1
  fi
  grep -q "true !== false" "$TRACES/mutant-output.txt" \
    || { cat "$TRACES/mutant-output.txt"; echo "mutant failed for the wrong reason"; return 1; }
  cat "$TRACES/mutant-output.txt"
  echo "submitted-field-guard mutant rejected"
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
  [[ -f "$OVERLAY/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Verify submitted inputs" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verify form action not bundled"; return 1; }
  grep -rq "Tamper next root" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "tamper probe not bundled"; return 1; }
  grep -rq "hx-post" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "htmx form attributes not bundled"; return 1; }
  grep -q "submitted verifier form" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "verify form copy not built"; return 1; }
  echo "astro build OK; htmx verifier form bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing runner d.ts landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-htmx.ts\tweb/src/components/aac-htmx.ts' "$CAND_DIR/LANDING" \
    || { echo "missing htmx adapter landing"; bad=1; }
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/components/elements.ts\tweb/src/components/elements.ts' "$CAND_DIR/LANDING" \
    || { echo "missing elements loader landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 7 ]] || { echo "landing should be exactly seven files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is runner, fundraise UI, adapter, docs, and tests only"
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
runner_result=fail
mutant_result=fail
build_result=fail
scope_result=fail

if run 01-source check_source; then source_result=pass; else fail=1; fi
if run 02-runner check_runner_tests; then runner_result=pass; else fail=1; fi
if run 03-mutant check_mutant_rejects_missing_field_guard; then mutant_result=pass; else fail=1; fi
if run 04-build check_build; then build_result=pass; else fail=1; fi
if run 05-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0084-fundraise-htmx-verify-form",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Make fundraise verification a submitted htmx verifier form instead of a reveal.",
  "checks": {
    "source": "$source_result",
    "runner": "$runner_result",
    "mutant": "$mutant_result",
    "build": "$build_result",
    "scope": "$scope_result"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
