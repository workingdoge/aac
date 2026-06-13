# Threshold Brief: cand-0025-registry-poseidon-regen

Generated: 2026-06-13T20:19:25Z
Status: validated
Intent: Regenerate the registry's bb verifiers + proof fixtures from the now-Poseidon2 circuits (cand-0024 cascade), restoring circuit<->verifier coherence: new HonkVerifier.sol (TRANSITION/1 vk) + NullifyHonkVerifier.sol (NULLIFY/1 vk, public contract renamed) + the four keccak-oracle fixtures (transition/nullify .proof/.pub) carrying the new poseidon commitment values. Registry.sol/test/Deploy/foundry unchanged (the test reads roots from the fixtures, no hardcoded values). forge test green (8, the real poseidon proofs verify on-chain); both verifiers + Registry under EIP-170.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/registry/src/HonkVerifier.sol` replaces `registry/src/HonkVerifier.sol`: +59/-59 lines vs live
- `cargo/registry/src/NullifyHonkVerifier.sol` replaces `registry/src/NullifyHonkVerifier.sol`: +59/-59 lines vs live
- `cargo/registry/test/fixtures/transition.proof` replaces `registry/test/fixtures/transition.proof`: +0/-0 lines vs live
- `cargo/registry/test/fixtures/transition.pub` replaces `registry/test/fixtures/transition.pub`: +0/-0 lines vs live
- `cargo/registry/test/fixtures/nullify.proof` replaces `registry/test/fixtures/nullify.proof`: +0/-0 lines vs live
- `cargo/registry/test/fixtures/nullify.pub` replaces `registry/test/fixtures/nullify.pub`: +0/-0 lines vs live

## Witnessed behavioral delta (task: regenerate the registry bb verifiers + keccak-oracle proof fixtures from the now-Poseidon2 circuits (cand-0024 cascade); new HonkVerifier + NullifyHonkVerifier vks + new transition/nullify fixtures; forge test green (8, real poseidon proofs verify on-chain); all three deployed contracts under EIP-170)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
