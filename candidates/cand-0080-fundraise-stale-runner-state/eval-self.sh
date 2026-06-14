#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0080-fundraise-stale-runner-state.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-stale-runner-state.XXXXXX)"
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
  local comp="$1" bad=0
  grep -q "isCurrentRunnerSummary(payload.summary)" "$comp" \
    || { echo "live response is not checked against current summary schema"; bad=1; }
  grep -q "runner summary schema is stale; restart fundraise demo runner" "$comp" \
    || { echo "missing stale-runner error"; bad=1; }
  grep -q "Array.isArray(candidate.fills)" "$comp" \
    || { echo "current-summary guard does not require fills"; bad=1; }
  grep -q "Array.isArray(candidate.opening_balances)" "$comp" \
    || { echo "current-summary guard does not require opening balances"; bad=1; }
  grep -q "Array.isArray(reconciliation.rows)" "$comp" \
    || { echo "current-summary guard does not require reconciliation rows"; bad=1; }
  grep -q "&& !!candidate.verifier" "$comp" \
    || { echo "current-summary guard does not require verifier"; bad=1; }
  grep -q "accepted && !reconciliationAvailable) return 'runner schema stale'" "$comp" \
    || { echo "missing stale book-reconciliation state"; bad=1; }
  grep -q "reconciliationRows.length" "$comp" \
    || { echo "render path does not distinguish absent reconciliation rows"; bad=1; }
  grep -q "reconciliationEmptyMessage(s.accepted, reconciliationAvailable)" "$comp" \
    || { echo "missing stale reconciliation empty-state message"; bad=1; }
  ! grep -q "s.reconciliation ?? { accepted: false, rows: \\[\\] }" "$comp" \
    || { echo "absent reconciliation still defaults to failed reconciliation"; bad=1; }
  ! grep -q "this.bookReconciliationState(s.accepted, booksClose)" "$comp" \
    || { echo "book state still lacks reconciliation-availability input"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise component treats accepted legacy runner summaries as stale, not mismatched"
}

check_source() {
  check_source_file "$CARGO/web/src/components/aac-fundraise-demo.ts"
}

check_mutant_rejects_false_mismatch() {
  local mutant="$WORK/mutant-false-mismatch.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/if \\(accepted && !reconciliationAvailable\\) return 'runner schema stale';/if (accepted && !reconciliationAvailable) return 'mismatch flagged';/" "$mutant"
  if check_source_file "$mutant" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "false-mismatch mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "false-mismatch mutant rejected"
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
  grep -rq "runner summary schema is stale" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "stale runner guard not bundled"; return 1; }
  grep -rq "runner schema stale" "$OVERLAY/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "stale reconciliation state not bundled"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); stale-runner state bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 1 ]] || { echo "landing should be exactly one file"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is one web component only"
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
if run 02-mutant check_mutant_rejects_false_mismatch; then mutant_result=pass; else fail=1; fi
if run 03-build check_build; then build_result=pass; else fail=1; fi
if run 04-scope check_scope; then scope_result=pass; else fail=1; fi

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0080-fundraise-stale-runner-state",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Treat accepted legacy runner summaries as stale runner state instead of a book mismatch.",
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
