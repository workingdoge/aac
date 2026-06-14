#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0087-fundraise-ledger-language.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-fundraise-ledger-language.XXXXXX)"
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

apply_landing_to_overlay() {
  while IFS=$' \t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$OVERLAY/$dst")"
    cp "$CAND_DIR/$src" "$OVERLAY/$dst"
  done < "$CAND_DIR/LANDING"
}

prepare_overlay() {
  if [[ "$OVERLAY_READY" -eq 1 ]]; then return 0; fi
  mkdir -p "$OVERLAY"
  for dir in bcc-runtime fundraise-runtime fundraise-provekit-adapter fundraise-workflow vnet-runtime design registry; do
    [[ -e "$ROOT/$dir" ]] && ln -s "$ROOT/$dir" "$OVERLAY/$dir"
  done
  if [[ -d "$ROOT/sites" ]]; then
    cp -cR "$ROOT/sites" "$OVERLAY/sites" 2>/dev/null \
      || cp -R "$ROOT/sites" "$OVERLAY/sites"
  fi
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
  apply_landing_to_overlay
  OVERLAY_READY=1
}

check_spec() {
  local spec="$CARGO/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md"
  local bad=0
  grep -q 'Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET, LEDGER/1, BCC/1, VNET/1' "$spec" \
    || { echo "FUNDRAISE-CLEARING/1 must cite LEDGER/1"; bad=1; }
  grep -q 'fundraise-specific statement surface over LEDGER/1' "$spec" \
    || { echo "spec missing LEDGER statement-surface framing"; bad=1; }
  grep -q 'FundraiseLedgerSurface' "$spec" \
    || { echo "spec missing ledger fibre object"; bad=1; }
  grep -q 'round_capacity_statement:    StatementRequest(statement_type = round_capacity)' "$spec" \
    || { echo "spec missing round_capacity statement request"; bad=1; }
  grep -q 'receipt_issuance_statement:  StatementRequest(statement_type = receipt_issuance)' "$spec" \
    || { echo "spec missing receipt_issuance statement request"; bad=1; }
  grep -q 'Private settlement transition' "$spec" \
    || { echo "spec missing private settlement transition obligation"; bad=1; }
  grep -q 'Balance-sheet statement' "$spec" \
    || { echo "spec missing balance-sheet statement obligation"; bad=1; }
  grep -q 'Receipt issuance statement' "$spec" \
    || { echo "spec missing receipt-issuance statement obligation"; bad=1; }
  grep -q 'not the object the user operates' "$spec" \
    || { echo "spec must demote VNET/BCC from user object"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "spec binds fundraise clearing to LEDGER/1 statement objects"
}

check_presentation() {
  local page="$CARGO/web/src/content/docs/fundraise.mdx"
  local component="$CARGO/web/src/components/aac-fundraise-demo.ts"
  local summary="$CARGO/web/src/data/fundraise-demo-summary.ts"
  local bad=0
  grep -q 'title: Private ledger settlement' "$page" \
    || { echo "page title not ledger-settlement oriented"; bad=1; }
  grep -q 'The flow is: issuer ledger pre-state' "$page" \
    || { echo "page missing ledger-flow opening"; bad=1; }
  grep -q 'round-capacity statement, selected subscription batch, private settlement' "$page" \
    || { echo "page missing middle ledger-flow steps"; bad=1; }
  grep -q 'issuer ledger post-state, and receipt-issuance statement' "$page" \
    || { echo "page missing ledger-flow close"; bad=1; }
  grep -q 'VNET is the amount-vector clearing check under the receipt drawer' "$page" \
    || { echo "page does not put VNET behind receipt drawer"; bad=1; }
  grep -q 'Issuer private ledger' "$component" \
    || { echo "component missing issuer ledger eyebrow"; bad=1; }
  grep -q 'Round capacity statement' "$component" \
    || { echo "component missing round capacity label"; bad=1; }
  grep -q 'Issuer ledger pre-state' "$component" \
    || { echo "component missing pre-state label"; bad=1; }
  grep -q 'Selected subscription batch' "$component" \
    || { echo "component missing subscription batch label"; bad=1; }
  grep -q 'Statement verifier inputs' "$component" \
    || { echo "component missing verifier form label"; bad=1; }
  grep -q 'Balance-sheet statement' "$component" \
    || { echo "component missing balance-sheet statement card"; bad=1; }
  grep -q 'Receipt issuance' "$component" \
    || { echo "component missing receipt issuance lane"; bad=1; }
  grep -q 'USDC capacity statement' "$summary" \
    || { echo "summary metrics not statement-oriented"; bad=1; }
  grep -q 'The round-capacity statement admitted the selected subscription batch.' "$summary" \
    || { echo "summary claims not ledger-statement oriented"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "presentation copy follows issuer ledger statement workflow"
}

check_stale_language() {
  local bad=0
  local files=(
    "$CARGO/web/src/content/docs/fundraise.mdx"
    "$CARGO/web/src/components/aac-fundraise-demo.ts"
    "$CARGO/web/src/data/fundraise-demo-summary.ts"
  )
  local pattern
  for pattern in \
    'Private order' \
    'order-fill' \
    'order fill' \
    'Open order' \
    'Starting balances' \
    'Submitted fills' \
    'Before/after state proof' \
    'state-verifier' \
    'state verifier not run' \
    'Generate proof'; do
    if grep -Rqi "$pattern" "${files[@]}"; then
      echo "stale presentation language remains: $pattern"
      bad=1
    fi
  done
  [[ "$bad" -eq 0 ]] && echo "stale proof-console and order-fill language removed"
}

check_landing() {
  local bad=0
  grep -qx 'cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md' "$CAND_DIR/LANDING" \
    || { echo "missing FUNDRAISE-CLEARING landing"; bad=1; }
  grep -qx 'cargo/web/src/content/docs/fundraise.mdx web/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise page landing"; bad=1; }
  grep -qx 'cargo/web/src/components/aac-fundraise-demo.ts web/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing fundraise component landing"; bad=1; }
  grep -qx 'cargo/web/src/data/fundraise-demo-summary.ts web/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing summary landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 4 ]] \
    || { echo "LANDING should contain exactly four cargo maps"; bad=1; }
  ! grep -q ' tools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q ' sites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is fundraise app spec plus fundraise web presentation only"
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
  grep -q "Private ledger settlement" "$OVERLAY/web/dist/fundraise/index.html" \
    || { echo "ledger settlement page title not built"; return 1; }
  grep -rq "Issuer ledger has capacity to settle" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "ledger headline not bundled"; return 1; }
  grep -rq "Statement verifier inputs" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "verifier form label not bundled"; return 1; }
  grep -rq "Receipt issuance" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "receipt issuance lane not bundled"; return 1; }
  echo "astro build OK; ledger-statement demo presentation bundled"
}

run() {
  local nm="$1" fn="$2" rc
  "$fn" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
spec_result=fail
presentation_result=fail
stale_result=fail
landing_result=fail
build_result=fail

if run 01-spec check_spec; then spec_result=pass; else fail=1; fi
if run 02-presentation check_presentation; then presentation_result=pass; else fail=1; fi
if run 03-stale check_stale_language; then stale_result=pass; else fail=1; fi
if run 04-landing check_landing; then landing_result=pass; else fail=1; fi
if run 05-build check_build; then build_result=pass; else fail=1; fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0087-fundraise-ledger-language",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Bind FUNDRAISE-CLEARING/1 and the fundraise demo presentation to LEDGER/1 ledger-state and statement vocabulary.",\n'
  printf '  "checks": {\n'
  printf '    "spec": "%s",\n' "$spec_result"
  printf '    "presentation": "%s",\n' "$presentation_result"
  printf '    "stale_language": "%s",\n' "$stale_result"
  printf '    "landing": "%s",\n' "$landing_result"
  printf '    "build": "%s"\n' "$build_result"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
