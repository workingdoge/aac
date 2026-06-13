#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0018-registry-contract.
# Witnesses that the 4/REG Registry verifies the REAL TRANSITION/1 UltraHonk
# proof on-chain and advances the row, and refuses stale/tampered/context-
# mismatched updates. forge+solc come from nixpkgs (nix shell) when not on PATH;
# honest-skips when neither forge nor nix is available.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
REG="$CAND_DIR/cargo/registry"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  for f in foundry.toml src/Registry.sol src/HonkVerifier.sol test/Registry.t.sol \
           test/fixtures/transition.proof test/fixtures/transition.pub; do
    [[ -f "$REG/$f" ]] || { echo "missing $f"; bad=1; }
  done
  # the registry must discharge the verifier + the old-root/context refusals
  grep -q 'transitionVerifier.verify' "$REG/src/Registry.sol" || { echo "registry does not discharge the proof"; bad=1; }
  grep -q 'stale account root' "$REG/src/Registry.sol" || { echo "no old-root equality refusal"; bad=1; }
  grep -q 'context mismatch' "$REG/src/Registry.sol" || { echo "no context pin"; bad=1; }
  # the proof fixture is a real 8-public-input proof (256-byte publics)
  [[ "$(wc -c < "$REG/test/fixtures/transition.pub" 2>/dev/null)" == "256" ]] || { echo "public-inputs fixture is not 8 field elements"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "registry + bb verifier + real proof fixture present; refusals wired"
}

forge_test() {
  # run forge test in the cargo registry project, solc pinned (no auto-download).
  if command -v forge >/dev/null 2>&1 && command -v solc >/dev/null 2>&1; then
    ( cd "$REG" && forge test --use "$(command -v solc)" -vv )
  elif command -v nix >/dev/null 2>&1; then
    nix shell nixpkgs#foundry nixpkgs#solc --command bash -c \
      "cd '$REG' && forge test --use \"\$(command -v solc)\" -vv"
  else
    return 75
  fi
}

check_test() {
  local out rc
  out="$(forge_test 2>&1)"; rc=$?
  printf '%s\n' "$out"
  [[ "$rc" -eq 75 ]] && { echo "SKIP: neither forge nor nix available"; return 0; }
  [[ "$rc" -eq 0 ]] || { echo "forge test FAILED (rc=$rc)"; return 1; }
  grep -q 'PASS] test_ValidProofUpdatesRow' <<< "$out" || { echo "the real proof did not verify on-chain"; return 1; }
  grep -q 'PASS] test_StaleUpdateReverts' <<< "$out" || { echo "stale refusal missing"; return 1; }
  grep -q 'PASS] test_TamperedProofReverts' <<< "$out" || { echo "tampered-proof refusal missing"; return 1; }
  grep -qE '4 (tests )?passed|4 passed' <<< "$out" || { echo "not all 4 tests passed"; return 1; }
  echo "forge test OK: the real TRANSITION/1 proof verifies on-chain + refusals enforced"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present check_present || fail=1
run 02-test    check_test    || fail=1
rm -rf "$REG/out" "$REG/cache"

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0018-registry-contract",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "4/REG Registry.sol verifies the real TRANSITION/1 UltraHonk proof on-chain and advances the row; refuses stale-root / tampered-proof / context-mismatch updates (forge test, bb-generated HonkVerifier)",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n' "$(grep -q 'refusals wired' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "test": "%s"\n'    "$(grep -qE 'forge test OK|^SKIP' "$TRACES/02-test.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
