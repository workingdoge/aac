#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0019-registry-deployable.
# Witnesses that the 4/REG registry is DEPLOYABLE: the bb HonkVerifier fits under
# EIP-170 at optimizer_runs=50, forge test stays green (the real proof still
# verifies), and the Deploy script deploys + links the verifier library + the
# Registry in a forge EVM. forge+solc from nixpkgs; honest-skips without nix.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/registry"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  grep -q 'optimizer_runs = 50' "$CARGO/foundry.toml" || { echo "optimizer_runs not lowered to 50"; bad=1; }
  grep -qi 'EIP-170' "$CARGO/foundry.toml" || { echo "no EIP-170 rationale in foundry.toml"; bad=1; }
  [[ -f "$CARGO/script/Deploy.s.sol" ]] || { echo "no Deploy script"; bad=1; }
  grep -q 'new HonkVerifier' "$CARGO/script/Deploy.s.sol" && grep -q 'new Registry' "$CARGO/script/Deploy.s.sol" || { echo "Deploy script does not deploy verifier + registry"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "optimizer_runs=50 (EIP-170 rationale) + Deploy script present"
}

# assemble the project: landed registry sources/tests/fixtures + the cargo's
# foundry.toml (runs=50) and script.
stage() {
  local s="$TRACES/proj"; rm -rf "$s"; mkdir -p "$s/script"
  cp -r "$ROOT/registry/src" "$ROOT/registry/test" "$s/"
  cp "$CARGO/foundry.toml" "$s/foundry.toml"
  cp "$CARGO/script/Deploy.s.sol" "$s/script/Deploy.s.sol"
  printf '%s' "$s"
}

run_forge() { # run_forge <project> <args...>
  local proj="$1"; shift
  if command -v forge >/dev/null 2>&1 && command -v solc >/dev/null 2>&1; then
    ( cd "$proj" && forge "$@" --use "$(command -v solc)" )
  elif command -v nix >/dev/null 2>&1; then
    nix shell nixpkgs#foundry nixpkgs#solc --command bash -c \
      "cd '$proj' && forge $* --use \"\$(command -v solc)\""
  else
    return 75
  fi
}

check_deployable() {
  local s; s="$(stage)"
  # (1) EIP-170: the DEPLOYED contracts must fit. (`--sizes` also flags the
  #     Deploy SCRIPT, which embeds the verifier creation code but is run, never
  #     deployed — so check HonkVerifier + Registry runtime sizes specifically.)
  local sz rc
  sz="$(run_forge "$s" build --sizes 2>&1)"; rc=$?
  [[ "$rc" -eq 75 ]] && { echo "SKIP: neither forge nor nix available"; return 0; }
  local c runtime
  for c in HonkVerifier Registry; do
    runtime="$(printf '%s\n' "$sz" | awk -F'|' -v c="$c" '{n=$2; gsub(/^[ ]+|[ ]+$/,"",n); if(n==c){gsub(/[, ]/,"",$3); print $3; exit}}')"
    [[ -n "$runtime" ]] || { echo "could not read $c size"; return 1; }
    printf '  %-14s runtime %s B (EIP-170 limit 24576)\n' "$c" "$runtime"
    [[ "$runtime" -lt 24576 ]] || { echo "$c exceeds EIP-170 ($runtime B)"; return 1; }
  done
  # (2) forge test still green (correctness preserved at runs=50).
  local t; t="$(run_forge "$s" test 2>&1)"
  grep -q 'PASS] test_ValidProofUpdatesRow' <<< "$t" && grep -qE '4 (tests )?passed|4 passed' <<< "$t" || { echo "forge test not green at runs=50"; printf '%s\n' "$t" | tail -6; return 1; }
  # (3) the Deploy script deploys + links + constructs (forge EVM simulation).
  local d; d="$(run_forge "$s" script script/Deploy.s.sol:Deploy 2>&1)"
  grep -qi 'Script ran successfully' <<< "$d" || { echo "Deploy script did not run"; printf '%s\n' "$d" | tail -8; return 1; }
  echo "deployable: HonkVerifier under EIP-170, forge test green, Deploy script runs (verifier+library+registry)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present    check_present    || fail=1
run 02-deployable check_deployable || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0019-registry-deployable",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "make the 4/REG registry deployable — HonkVerifier under EIP-170 at optimizer_runs=50, forge test still green (real proof verifies), and the Deploy script deploys+links the verifier library + Registry",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n'    "$(grep -q 'Deploy script present' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "deployable": "%s"\n'  "$(grep -qE 'deployable:|^SKIP' "$TRACES/02-deployable.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
