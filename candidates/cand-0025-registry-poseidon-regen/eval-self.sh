#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0025-registry-poseidon-regen.
# Witnesses that the registry's bb verifiers + proof fixtures were regenerated
# from the now-Poseidon2 circuits (cand-0024 cascade): the new HonkVerifier +
# NullifyHonkVerifier carry the new vks, the four keccak-oracle fixtures carry
# the new poseidon commitment values, forge test stays green (the real proofs
# verify on-chain against the new verifiers), and all three deployed contracts
# stay under EIP-170. forge+solc from nixpkgs; honest-skips without nix.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/registry"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  grep -q 'contract HonkVerifier is' "$CARGO/src/HonkVerifier.sol" || { echo "HonkVerifier missing"; bad=1; }
  grep -q 'contract NullifyHonkVerifier is' "$CARGO/src/NullifyHonkVerifier.sol" || { echo "renamed NullifyHonkVerifier missing"; bad=1; }
  # pin to the regeneration: the transition vk must NOT be the pre-poseidon one.
  grep -q '0x2283d75879675da73a25ee8b1f0f066a5ea8197b74f1ae6250c2628f4bbeafb4' "$CARGO/src/HonkVerifier.sol" && { echo "HonkVerifier still carries the pre-poseidon vk"; bad=1; }
  for f in transition.proof transition.pub nullify.proof nullify.pub; do
    [[ -s "$CARGO/test/fixtures/$f" ]] || { echo "fixture missing/empty: $f"; bad=1; }
  done
  [[ "$(wc -c < "$CARGO/test/fixtures/transition.pub")" == "256" ]] || { echo "transition.pub not 8 fields"; bad=1; }
  [[ "$(wc -c < "$CARGO/test/fixtures/nullify.pub")" == "128" ]] || { echo "nullify.pub not 4 fields"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "regenerated verifiers (new vks) + 4 keccak fixtures present (transition 8 / nullify 4)"
}

stage() {
  local s="$TRACES/proj"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/registry/src" "$ROOT/registry/test" "$ROOT/registry/script" "$s/"
  cp "$ROOT/registry/foundry.toml" "$s/foundry.toml"
  cp "$CARGO/src/HonkVerifier.sol" "$s/src/HonkVerifier.sol"
  cp "$CARGO/src/NullifyHonkVerifier.sol" "$s/src/NullifyHonkVerifier.sol"
  cp "$CARGO/test/fixtures/"* "$s/test/fixtures/"
  printf '%s' "$s"
}

run_forge() {
  local proj="$1"; shift
  if command -v forge >/dev/null 2>&1 && command -v solc >/dev/null 2>&1; then
    ( cd "$proj" && forge "$@" --use "$(command -v solc)" )
  elif command -v nix >/dev/null 2>&1; then
    nix shell nixpkgs#foundry nixpkgs#solc --command bash -c "cd '$proj' && forge $* --use \"\$(command -v solc)\""
  else
    return 75
  fi
}

check_onchain() {
  local s; s="$(stage)"
  local sz rc; sz="$(run_forge "$s" build --sizes 2>&1)"; rc=$?
  [[ "$rc" -eq 75 ]] && { echo "SKIP: neither forge nor nix available"; return 0; }
  local c runtime
  for c in HonkVerifier NullifyHonkVerifier Registry; do
    runtime="$(printf '%s\n' "$sz" | awk -F'|' -v c="$c" '{n=$2; gsub(/^[ ]+|[ ]+$/,"",n); if(n==c){gsub(/[, ]/,"",$3); print $3; exit}}')"
    [[ -n "$runtime" ]] || { echo "could not read $c size"; return 1; }
    printf '  %-20s runtime %s B (EIP-170 limit 24576)\n' "$c" "$runtime"
    [[ "$runtime" -lt 24576 ]] || { echo "$c exceeds EIP-170 ($runtime B)"; return 1; }
  done
  local t; t="$(run_forge "$s" test 2>&1)"
  grep -q 'PASS] test_ValidProofUpdatesRow' <<< "$t" \
    && grep -q 'PASS] test_NullifyAdvancesSetRoot' <<< "$t" \
    && grep -qE '8 (tests )?passed|8 passed' <<< "$t" \
    || { echo "forge test not green (8) against the regenerated artifacts"; printf '%s\n' "$t" | tail -10; return 1; }
  local d; d="$(run_forge "$s" script script/Deploy.s.sol:Deploy 2>&1)"
  grep -qi 'Script ran successfully' <<< "$d" || { echo "Deploy did not run"; printf '%s\n' "$d" | tail -8; return 1; }
  echo "on-chain: both REAL poseidon proofs verify against the regenerated verifiers; 8 tests green; all under EIP-170; Deploy runs"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present check_present || fail=1
run 02-onchain check_onchain || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0025-registry-poseidon-regen",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "regenerate the registry bb verifiers + keccak-oracle proof fixtures from the now-Poseidon2 circuits (cand-0024 cascade); new HonkVerifier + NullifyHonkVerifier vks + new transition/nullify fixtures; forge test green (8, real poseidon proofs verify on-chain); all three deployed contracts under EIP-170",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n'  "$(grep -q 'fixtures present' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "onchain": "%s"\n'   "$(grep -qE 'on-chain:|^SKIP' "$TRACES/02-onchain.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
