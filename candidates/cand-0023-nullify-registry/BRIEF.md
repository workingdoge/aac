# Threshold Brief: cand-0023-nullify-registry

Generated: 2026-06-13T19:56:41Z
Status: validated
Intent: Wire the enshrined NULLIFY/1 target into 4/REG: the registry maintains a per-row historical nullifier-SET root (the strictly-sorted consumed-nullifier set, TAG_SET) advanced by advanceNullifier(namehash, proof, publicInputs[4]) which discharges a SECOND pinned bb verifier (NullifyHonkVerifier) over the NULLIFY/1 ABI [first_root,last_root,sequence_commitment,count] -- old-set-root equality (the concurrency rule), count==1, and the proof. This is the historical anti-replay guard on-chain, distinct from TRANSITION/1's batch-local insertion-chain nullifier_root (different representation: TAG_SET sorted-set fold vs TAG_NULLIFIER insertion chain), so no transition circuit/fixture change. EVENT-COMPLETE/1 is NOT wired (4/REG S5: the base registry MUST NOT require it). Real NULLIFY/1 keccak-oracle proof verifies on-chain in forge; stale set root / tampered proof / count!=1 refused.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/registry/src/Registry.sol` replaces `registry/src/Registry.sol`: +65/-8 lines vs live
- `cargo/registry/src/NullifyHonkVerifier.sol` is NEW at `registry/src/NullifyHonkVerifier.sol`: 2438 lines
- `cargo/registry/test/Registry.t.sol` replaces `registry/test/Registry.t.sol`: +67/-14 lines vs live
- `cargo/registry/test/fixtures/nullify.proof` is NEW at `registry/test/fixtures/nullify.proof`: 36 lines
- `cargo/registry/test/fixtures/nullify.pub` is NEW at `registry/test/fixtures/nullify.pub`: 0 lines
- `cargo/registry/script/Deploy.s.sol` replaces `registry/script/Deploy.s.sol`: +9/-6 lines vs live
- `cargo/registry/README.md` replaces `registry/README.md`: +58/-28 lines vs live

## Witnessed behavioral delta (task: wire the enshrined NULLIFY/1 target into 4/REG: a per-row historical nullifier-set root advanced by advanceNullifier, discharging a second pinned bb verifier (NullifyHonkVerifier) over a real keccak-oracle NULLIFY/1 proof on-chain; stale set root / tampered proof / count!=1 refused; EVENT-COMPLETE/1 NOT enshrined (4/REG S5); both verifiers + Registry under EIP-170; forge test green (8); Deploy runs)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
