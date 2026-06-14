#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0069-fundraise-private-network-cors.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-fundraise-pna-cors.XXXXXX)"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi

head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

apply_landing() {
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$WORK/$dst")"
    cp "$CAND_DIR/$src" "$WORK/$dst"
  done < "$CAND_DIR/LANDING"
}

prepare_overlay() {
  cp -R "$ROOT/fundraise-demo-runner" "$WORK/fundraise-demo-runner"
  ln -s "$ROOT/fundraise-provekit-adapter" "$WORK/fundraise-provekit-adapter"
  ln -s "$ROOT/fundraise-workflow" "$WORK/fundraise-workflow"
  ln -s "$ROOT/fundraise-runtime" "$WORK/fundraise-runtime"
  ln -s "$ROOT/fundraise-authorizer" "$WORK/fundraise-authorizer"
  ln -s "$ROOT/world-app" "$WORK/world-app"
  ln -s "$ROOT/sites" "$WORK/sites"
  apply_landing
}

check_source_file() {
  local src="$1" types="$2" test="$3" bad=0
  grep -q 'export function buildFundraiseDemoCorsHeaders' "$src" \
    || { echo "missing exported CORS header builder"; bad=1; }
  grep -q '"access-control-allow-private-network": "true"' "$src" \
    || { echo "missing private-network CORS allowance"; bad=1; }
  grep -q '"vary": "Origin, Access-Control-Request-Private-Network"' "$src" \
    || { echo "missing private-network Vary header"; bad=1; }
  grep -q 'writeCorsPreflight(response, input.cors_origin)' "$src" \
    || { echo "preflight does not use shared CORS headers"; bad=1; }
  grep -q 'buildFundraiseDemoCorsHeaders' "$types" \
    || { echo "types do not expose CORS header builder"; bad=1; }
  grep -q 'buildFundraiseDemoCorsHeaders("http://127.0.0.1:4328")' "$test" \
    || { echo "test does not exercise browser-origin CORS helper"; bad=1; }
  grep -q 'corsHeaders\["access-control-allow-private-network"\]' "$test" \
    || { echo "test does not assert private-network response header"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "runner emits and tests private-network CORS preflight headers"
}

check_source() {
  check_source_file "$RUNNER/src/index.mjs" "$RUNNER/src/index.d.ts" "$RUNNER/test/run-tests.mjs"
}

check_mutant_rejects_missing_private_network() {
  local mutant_src="$WORK/mutant-index.mjs"
  local mutant_test="$WORK/mutant-test.mjs"
  cp "$RUNNER/src/index.mjs" "$mutant_src"
  cp "$RUNNER/src/index.d.ts" "$WORK/mutant-index.d.ts"
  cp "$RUNNER/test/run-tests.mjs" "$mutant_test"
  perl -0pi -e 's/\n    "access-control-allow-private-network": "true",//g' "$mutant_src"
  if check_source_file "$mutant_src" "$WORK/mutant-index.d.ts" "$mutant_test" >/tmp/aac-pna-mutant.$$ 2>&1; then
    cat /tmp/aac-pna-mutant.$$
    rm -f /tmp/aac-pna-mutant.$$
    echo "mutant unexpectedly passed"
    return 1
  fi
  cat /tmp/aac-pna-mutant.$$
  rm -f /tmp/aac-pna-mutant.$$
  echo "missing-private-network-header mutant rejected"
}

check_unit() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  )
}

check_landing_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/src/index.d.ts\tfundraise-demo-runner/src/index.d.ts' "$CAND_DIR/LANDING" \
    || { echo "missing runner type landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  [[ "$(grep -vc '^#\\|^$' "$CAND_DIR/LANDING")" -eq 3 ]] || { echo "landing should be runner source, types, and test only"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is runner source and unit test only"
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
run 02-mutant check_mutant_rejects_missing_private_network || fail=1
run 03-unit check_unit || fail=1
run 04-scope check_landing_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0069-fundraise-private-network-cors",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Allow browser private-network preflights against the fundraise runner.",
  "checks": {
    "source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "mutant": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "unit": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
