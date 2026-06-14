#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0074-fundraise-order-fill-ui.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-order-fill-ui.XXXXXX)"
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
  local comp="$1" page="$2" summary="$3" bad=0
  grep -q "Private SAFE order ready to fill" "$comp" || { echo "component missing order-ready headline"; bad=1; }
  grep -q "Fill order live" "$comp" || { echo "component missing order-fill action label"; bad=1; }
  grep -q "Order fill ticket" "$comp" || { echo "component missing order ticket region"; bad=1; }
  grep -q 'Sell ${orderUnits} restricted receipt units' "$comp" || { echo "component missing order economic line"; bad=1; }
  grep -q "investor-a" "$comp" || { echo "component missing first fill row"; bad=1; }
  grep -q "investor-b" "$comp" || { echo "component missing second fill row"; bad=1; }
  grep -q "ProveKit cleared order" "$comp" || { echo "component missing order-clearing proof label"; bad=1; }
  grep -q "Receipt tokens" "$comp" || { echo "component missing settlement-token lane"; bad=1; }
  grep -q "Private order fill" "$page" || { echo "page title not reframed"; bad=1; }
  grep -q "two investors fill the order" "$page" || { echo "page copy does not name fills"; bad=1; }
  grep -q "prepare/prove/verify for the order-fill packet" "$page" || { echo "page does not bind live runner to order-fill packet"; bad=1; }
  grep -q "private order fill" "$summary" || { echo "captured summary claim not reframed"; bad=1; }
  ! grep -q "Run live proof" "$comp" || { echo "old generic run label remains"; bad=1; }
  ! grep -q "target cash" "$comp" || { echo "old generic target cash label remains"; bad=1; }
  ! grep -q "subscribers in packet" "$comp" || { echo "old subscriber packet label remains"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "fundraise page presents a private order fill with visible fills and proof states"
}

check_source() {
  check_source_file \
    "$CARGO/web/src/components/aac-fundraise-demo.ts" \
    "$CARGO/web/src/content/docs/fundraise.mdx" \
    "$CARGO/web/src/data/fundraise-demo-summary.ts"
}

check_mutant_rejects_generic_copy() {
  local mutant="$WORK/mutant-generic.ts"
  cp "$CARGO/web/src/components/aac-fundraise-demo.ts" "$mutant"
  perl -0pi -e "s/Fill order live/Run live proof/g; s/USDC order size/target cash/g; s/fills in batch/subscribers in packet/g; s/ProveKit cleared order/ProveKit accepted VNET/g" "$mutant"
  if check_source_file "$mutant" "$CARGO/web/src/content/docs/fundraise.mdx" "$CARGO/web/src/data/fundraise-demo-summary.ts" > "$TRACES/mutant-output.txt" 2>&1; then
    cat "$TRACES/mutant-output.txt"
    echo "generic-copy mutant unexpectedly passed"
    return 1
  fi
  cat "$TRACES/mutant-output.txt"
  echo "generic-copy mutant rejected"
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
  grep -rq "Fill order live" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "order-fill action label not bundled"; return 1; }
  grep -rq "Order fill ticket" "$WORK/web/dist/_astro/"*.js 2>/dev/null \
    || { echo "order ticket not bundled"; return 1; }
  grep -q "Private order fill" "$WORK/web/dist/fundraise/index.html" \
    || { echo "order-fill page title not built"; return 1; }
  echo "astro build OK ($(grep -oE '[0-9]+ page\\(s\\) built' "$TRACES/build.txt" | head -1)); order-fill UI bundled"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/web/src/components/aac-fundraise-demo.ts\tweb/src/components/aac-fundraise-demo.ts' "$CAND_DIR/LANDING" \
    || { echo "missing component landing"; bad=1; }
  grep -qx $'cargo/web/src/content/docs/fundraise.mdx\tweb/src/content/docs/fundraise.mdx' "$CAND_DIR/LANDING" \
    || { echo "missing page landing"; bad=1; }
  grep -qx $'cargo/web/src/data/fundraise-demo-summary.ts\tweb/src/data/fundraise-demo-summary.ts' "$CAND_DIR/LANDING" \
    || { echo "missing captured summary landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 3 ]] || { echo "landing should be exactly three web files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is fundraise UI/page/captured summary only"
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
run 02-mutant check_mutant_rejects_generic_copy || fail=1
run 03-build check_build || fail=1
run 04-scope check_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0074-fundraise-order-fill-ui",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Reframe the fundraise page as a private order-fill demo with coherent controls and visible fill economics.",
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
