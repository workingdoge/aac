# Threshold Brief: cand-0018-registry-contract

Generated: 2026-06-13T17:55:08Z
Status: validated
Intent: The 4/REG root registry as a deployable Solidity contract at registry/ (Foundry): Registry.sol implements the TRANSITION/1 update rule -- old-root equality (the concurrency rule), context pin, proof discharge via the bb-generated UltraHonk verifier, atomic root advance + fact_fold chaining + nonce. Verifies the REAL TRANSITION/1 proof on-chain (keccak oracle). forge test green: valid proof advances the row; stale/tampered/context-mismatch refused. Closes the pipeline circuit -> bb proof -> solidity verifier -> registry.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/registry/foundry.toml` is NEW at `registry/foundry.toml`: 9 lines
- `cargo/registry/README.md` is NEW at `registry/README.md`: 45 lines
- `cargo/registry/src/Registry.sol` is NEW at `registry/src/Registry.sol`: 84 lines
- `cargo/registry/src/HonkVerifier.sol` is NEW at `registry/src/HonkVerifier.sol`: 2438 lines
- `cargo/registry/test/Registry.t.sol` is NEW at `registry/test/Registry.t.sol`: 67 lines
- `cargo/registry/test/fixtures/transition.proof` is NEW at `registry/test/fixtures/transition.proof`: 48 lines
- `cargo/registry/test/fixtures/transition.pub` is NEW at `registry/test/fixtures/transition.pub`: 0 lines

## Witnessed behavioral delta (task: 4/REG Registry.sol verifies the real TRANSITION/1 UltraHonk proof on-chain and advances the row; refuses stale-root / tampered-proof / context-mismatch updates (forge test, bb-generated HonkVerifier))

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
