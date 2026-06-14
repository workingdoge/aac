#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0077-fundraise-reconciliation-language.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-reconciliation-language.XXXXXX)"
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
  mkdir -p "$WORK/web"
  cp "$ROOT/web/package.json" "$WORK/web/package.json"
  cp "$ROOT/web/astro.config.mjs" "$WORK/web/astro.config.mjs"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$WORK/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$WORK/web/scripts"
  cp -R "$ROOT/web/src" "$WORK/web/src"
  cp -R "$ROOT/web/public" "$WORK/web/public"
  ln -s "$ROOT/design" "$WORK/design"
  ln -s "$ROOT/sites" "$WORK/sites"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$WORK/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$WORK/web/node_modules"
  fi
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$WORK/$dst")"
    cp "$CAND_DIR/$src" "$WORK/$dst"
  done < "$CAND_DIR/LANDING"
}

check_source_file() {
  local comp="$1" page="$2" bad=0
  grep -q "Book reconciliation" "$comp" || { echo "component missing reconciliation label"; bad=1; }
  grep -q 'aria-label="Book reconciliation"' "$comp" || { echo "component aria label still not reconciliation"; bad=1; }
  grep -q "bookReconciliationState" "$comp" || { echo "component missing reconciliation state helper"; bad=1; }
  grep -q "ready to reconcile" "$comp" || { echo "component missing pending reconciliation state"; bad=1; }
  grep -q "reconciling books" "$comp" || { echo "component missing running reconciliation state"; bad=1; }
  grep -q "books reconciled" "$comp" || { echo "component missing reconciled state"; bad=1; }
  grep -q "book-state.reconciled" "$comp" || { echo "component missing reconciled class"; bad=1; }
  grep -q "Opening books + swap deltas close the issuer row" "$comp" || { echo "component lost closing-books thesis"; bad=1; }
  grep -q "After the swap, the console reconciles the issuer books" "$page" || { echo "page copy does not say reconciles"; bad=1; }
  ! grep -q "Book verification" "$comp" || { echo "component still labels closing-books panel as verification"; bad=1; }
  ! grep -q "bookVerificationState" "$comp" || { echo "component still carries verification helper"; bad=1; }
  ! grep -q "ready to verify" "$comp" || { echo "component still says ready to verify"; bad=1; }
  ! grep -q "checking books" "$comp" || { echo "component still says checking books"; bad=1; }
  ! grep -q "books verified" "$comp" || { echo "component still says books verified"; bad=1; }
  ! grep -q "console verifies the issuer books" "$page" || { echo "page copy still overclaims verifier"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise closing-books panel uses reconciliation language, not verifier language"
}

check_source() {
  check_source_file \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx"
}

check_mutant_rejects_verifier_overclaim() {
  local mutant="$WORK/mutant-verifier-overclaim.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/Book reconciliation/Book verification/g; s/bookReconciliationState/bookVerificationState/g; s/ready to reconcile/ready to verify/g; s/reconciling books/checking books/g; s/books reconciled/books verified/g; s/book-state\\.reconciled/book-state.verified/g" "$mutant"
  if check_source_file "$mutant" "$CARGO/web/src/content/docs/fundraise.mdx" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "verifier-overclaim mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "verifier-overclaim mutant rejected"
}

check_build() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  [[ -f "$WORK/web/dist/fundraise/index.html" ]] || { echo "/fundraise not built"; return 1; }
  grep -rq "Book reconciliation" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "book reconciliation label not bundled"; return 1; }
  grep -rq "books reconciled" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "reconciled state not bundled"; return 1; }
  grep -q "console reconciles the issuer books" "$WORK/web/dist/fundraise/index.html" \
    || { echo "fundraise reconciliation copy not built"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); reconciliation language bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 2 ]] || { echo "landing should be exactly two web files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is fundraise component/page only"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-source check_source || fail=1
run 02-mutant check_mutant_rejects_verifier_overclaim || fail=1
run 03-build check_build || fail=1
run 04-scope check_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0077-fundraise-reconciliation-language",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Remove verifier overclaim from the fundraise closing-books UI.",
  "checks": {
    "source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "mutant": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "build": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
