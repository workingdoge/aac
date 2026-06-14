#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0073-provekit-bin-path.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
RUNNER="$CARGO/fundraise-demo-runner"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-provekit-bin-path.XXXXXX)"
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

check_source() {
  local bad=0
  grep -q "resolveFundraiseProveKitBin(input.provekit_bin, repoRoot)" "$RUNNER/src/index.mjs" \
    || { echo "runner does not normalize provekit_bin at repo-root scope"; bad=1; }
  grep -q "inputProveKitBin ?? process.env.PROVEKIT_BIN" "$RUNNER/src/index.mjs" \
    || { echo "runner does not cover PROVEKIT_BIN env"; bad=1; }
  grep -q "looksLikeExecutablePath" "$RUNNER/src/index.mjs" \
    || { echo "runner does not distinguish PATH command names from path-like values"; bad=1; }
  grep -q "return resolve(repoRoot, provekitBin)" "$RUNNER/src/index.mjs" \
    || { echo "relative path-like binary is not resolved against repoRoot"; bad=1; }
  grep -q "nix build .#provekit" "$RUNNER/README.md" \
    || { echo "README does not document building the ProveKit binary"; bad=1; }
  grep -q "repo-relative path like" "$RUNNER/README.md" \
    || { echo "README does not document repo-relative PROVEKIT_BIN behavior"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "source binds path-like ProveKit binary values before temp-cwd execution"
}

check_unit() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  prepare_overlay
  (
    cd "$WORK/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs &&
      "$NODE_BIN" --check src/index.mjs
  )
}

check_mutant() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WORK/fundraise-demo-runner" ]] || prepare_overlay
  cp "$WORK/fundraise-demo-runner/src/index.mjs" "$WORK/fundraise-demo-runner/src/index.mjs.before-mutant"
  perl -0pi -e 's/const provekitBin = resolveFundraiseProveKitBin\(input\.provekit_bin, repoRoot\);/const provekitBin = input.provekit_bin;/' "$WORK/fundraise-demo-runner/src/index.mjs"
  (
    cd "$WORK/fundraise-demo-runner" &&
      "$NODE_BIN" test/run-tests.mjs
  ) > "$TRACES/mutant-output.txt" 2>&1
  local rc=$?
  mv "$WORK/fundraise-demo-runner/src/index.mjs.before-mutant" "$WORK/fundraise-demo-runner/src/index.mjs"
  if [[ "$rc" -eq 0 ]]; then
    cat "$TRACES/mutant-output.txt"
    echo "mutant unexpectedly passed with unresolved PROVEKIT_BIN"
    return 1
  fi
  grep -q "result/bin/provekit-cli" "$TRACES/mutant-output.txt" \
    || { cat "$TRACES/mutant-output.txt"; echo "mutant failed for the wrong reason"; return 1; }
  echo "unresolved relative PROVEKIT_BIN mutant rejected"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/fundraise-demo-runner/src/index.mjs\tfundraise-demo-runner/src/index.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner source landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/test/run-tests.mjs\tfundraise-demo-runner/test/run-tests.mjs' "$CAND_DIR/LANDING" \
    || { echo "missing runner test landing"; bad=1; }
  grep -qx $'cargo/fundraise-demo-runner/README.md\tfundraise-demo-runner/README.md' "$CAND_DIR/LANDING" \
    || { echo "missing runner README landing"; bad=1; }
  [[ "$(grep -vc '^#\|^$' "$CAND_DIR/LANDING")" -eq 3 ]] || { echo "landing should contain exactly three runner files"; bad=1; }
  ! grep -q $'\ttools/' "$CAND_DIR/LANDING" || { echo "unexpected tools landing"; bad=1; }
  ! grep -q $'\tsites/premath/' "$CAND_DIR/LANDING" || { echo "unexpected premath landing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is demo runner only"
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
run 02-unit check_unit || fail=1
run 03-mutant check_mutant || fail=1
run 04-scope check_scope || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0073-provekit-bin-path",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Resolve relative ProveKit binary paths before the runner switches into the temp circuit workdir.",
  "checks": {
    "source": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "unit": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "mutant": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "scope": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
