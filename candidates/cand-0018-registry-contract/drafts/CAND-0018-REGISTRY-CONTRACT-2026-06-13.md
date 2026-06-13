# cand-0018-registry-contract (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0018-registry-contract-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: The 4/REG root registry as a deployable Solidity contract at registry/ (Foundry): Registry.sol implements the TRANSITION/1 update rule -- old-root equality (the concurrency rule), context pin, proof discharge via the bb-generated UltraHonk verifier, atomic root advance + fact_fold chaining + nonce. Verifies the REAL TRANSITION/1 proof on-chain (keccak oracle). forge test green: valid proof advances the row; stale/tampered/context-mismatch refused. Closes the pipeline circuit -> bb proof -> solidity verifier -> registry.
  source: candidates/cand-0018-registry-contract/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0018-registry-contract/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0018-REGISTRY-CONTRACT-2026-06-13.md
```
