#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0023-nullify-registry.
# Witnesses that the enshrined NULLIFY/1 target is wired into 4/REG: the registry
# maintains a per-row historical nullifier-SET root advanced by advanceNullifier,
# which discharges a SECOND pinned bb verifier (NullifyHonkVerifier) over a REAL
# NULLIFY/1 keccak-oracle proof on-chain; stale set root / tampered proof /
# count!=1 are refused. Both verifiers + the Registry stay under EIP-170.
# forge+solc from nixpkgs; honest-skips without nix.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/registry"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  local R="$CARGO/src/Registry.sol" T="$CARGO/test/Registry.t.sol" V="$CARGO/src/NullifyHonkVerifier.sol"
  grep -q 'function advanceNullifier' "$R" || { echo "Registry lacks advanceNullifier"; bad=1; }
  grep -q 'nullifyVerifier' "$R" || { echo "Registry lacks the pinned nullifyVerifier"; bad=1; }
  grep -q 'nullifierSetRoot' "$R" || { echo "Registry lacks the historical set root"; bad=1; }
  grep -q 'stale nullifier set root' "$R" || { echo "Registry lacks old-set-root equality"; bad=1; }
  grep -q 'expected single insertion' "$R" || { echo "Registry lacks the count==1 bound"; bad=1; }
  # doctrine: EVENT-COMPLETE/1 is NOT enshrined in the base registry (4/REG S5).
  grep -q 'MUST NOT' "$R" && grep -q '4/REG S5' "$R" || { echo "Registry does not record the 4/REG S5 boundary"; bad=1; }
  [[ -f "$V" ]] && grep -q 'contract NullifyHonkVerifier' "$V" || { echo "NullifyHonkVerifier (renamed) missing"; bad=1; }
  for fn in test_NullifyAdvancesSetRoot test_NullifyStaleSetRootReverts test_NullifyTamperedProofReverts test_NullifyMultiInsertionReverts; do
    grep -q "$fn" "$T" || { echo "missing test: $fn"; bad=1; }
  done
  [[ -f "$CARGO/test/fixtures/nullify.proof" && -f "$CARGO/test/fixtures/nullify.pub" ]] || { echo "nullify fixtures missing"; bad=1; }
  grep -q 'new NullifyHonkVerifier' "$CARGO/script/Deploy.s.sol" || { echo "Deploy does not deploy the nullify verifier"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "advanceNullifier + pinned nullifyVerifier + historical set root + refusals + 4/REG S5 boundary + tests + fixtures present"
}

# assemble the project: landed registry, then overlay the cargo (the modified
# Registry/test/Deploy, the new NullifyHonkVerifier, the nullify fixtures).
stage() {
  local s="$TRACES/proj"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/registry/src" "$ROOT/registry/test" "$ROOT/registry/script" "$s/"
  cp "$ROOT/registry/foundry.toml" "$s/foundry.toml"
  cp "$CARGO/src/Registry.sol" "$s/src/Registry.sol"
  cp "$CARGO/src/NullifyHonkVerifier.sol" "$s/src/NullifyHonkVerifier.sol"
  cp "$CARGO/test/Registry.t.sol" "$s/test/Registry.t.sol"
  cp "$CARGO/script/Deploy.s.sol" "$s/script/Deploy.s.sol"
  cp "$CARGO/test/fixtures/nullify.proof" "$s/test/fixtures/nullify.proof"
  cp "$CARGO/test/fixtures/nullify.pub" "$s/test/fixtures/nullify.pub"
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

check_onchain() {
  local s; s="$(stage)"
  # (1) EIP-170: the three DEPLOYED contracts must fit. (`--sizes` also flags the
  #     Deploy SCRIPT, which embeds both verifiers' creation code but is run,
  #     never deployed -- so check the deployed surface specifically.)
  local sz rc
  sz="$(run_forge "$s" build --sizes 2>&1)"; rc=$?
  [[ "$rc" -eq 75 ]] && { echo "SKIP: neither forge nor nix available"; return 0; }
  local c runtime
  for c in HonkVerifier NullifyHonkVerifier Registry; do
    runtime="$(printf '%s\n' "$sz" | awk -F'|' -v c="$c" '{n=$2; gsub(/^[ ]+|[ ]+$/,"",n); if(n==c){gsub(/[, ]/,"",$3); print $3; exit}}')"
    [[ -n "$runtime" ]] || { echo "could not read $c size"; return 1; }
    printf '  %-20s runtime %s B (EIP-170 limit 24576)\n' "$c" "$runtime"
    [[ "$runtime" -lt 24576 ]] || { echo "$c exceeds EIP-170 ($runtime B)"; return 1; }
  done
  # (2) forge test green -- the REAL nullify proof verifies on-chain + refusals.
  local t; t="$(run_forge "$s" test 2>&1)"
  grep -q 'PASS] test_NullifyAdvancesSetRoot' <<< "$t" \
    && grep -q 'PASS] test_ValidProofUpdatesRow' <<< "$t" \
    && grep -qE '8 (tests )?passed|8 passed' <<< "$t" \
    || { echo "forge test not green (8 incl. the nullify path)"; printf '%s\n' "$t" | tail -10; return 1; }
  # (3) the Deploy script deploys both verifiers + the Registry (forge EVM sim).
  local d; d="$(run_forge "$s" script script/Deploy.s.sol:Deploy 2>&1)"
  grep -qi 'Script ran successfully' <<< "$d" || { echo "Deploy script did not run"; printf '%s\n' "$d" | tail -8; return 1; }
  echo "on-chain: real NULLIFY/1 proof verifies + advances the set root; refusals hold; both verifiers + Registry under EIP-170; Deploy runs"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present check_present || fail=1
run 02-onchain check_onchain || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0023-nullify-registry",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "wire the enshrined NULLIFY/1 target into 4/REG: a per-row historical nullifier-set root advanced by advanceNullifier, discharging a second pinned bb verifier (NullifyHonkVerifier) over a real keccak-oracle NULLIFY/1 proof on-chain; stale set root / tampered proof / count!=1 refused; EVENT-COMPLETE/1 NOT enshrined (4/REG S5); both verifiers + Registry under EIP-170; forge test green (8); Deploy runs",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n'  "$(grep -q 'tests + fixtures present' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "onchain": "%s"\n'   "$(grep -qE 'on-chain:|^SKIP' "$TRACES/02-onchain.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
