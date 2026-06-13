# cand-0025-registry-poseidon-regen (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0025-registry-poseidon-regen-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Regenerate the registry's bb verifiers + proof fixtures from the now-Poseidon2 circuits (cand-0024 cascade), restoring circuit<->verifier coherence: new HonkVerifier.sol (TRANSITION/1 vk) + NullifyHonkVerifier.sol (NULLIFY/1 vk, public contract renamed) + the four keccak-oracle fixtures (transition/nullify .proof/.pub) carrying the new poseidon commitment values. Registry.sol/test/Deploy/foundry unchanged (the test reads roots from the fixtures, no hardcoded values). forge test green (8, the real poseidon proofs verify on-chain); both verifiers + Registry under EIP-170.
  source: candidates/cand-0025-registry-poseidon-regen/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0025-registry-poseidon-regen/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0025-REGISTRY-POSEIDON-REGEN-2026-06-13.md
```
