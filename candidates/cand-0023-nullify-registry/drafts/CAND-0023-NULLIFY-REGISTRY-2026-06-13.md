# cand-0023-nullify-registry (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0023-nullify-registry-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Wire the enshrined NULLIFY/1 target into 4/REG: the registry maintains a per-row historical nullifier-SET root (the strictly-sorted consumed-nullifier set, TAG_SET) advanced by advanceNullifier(namehash, proof, publicInputs[4]) which discharges a SECOND pinned bb verifier (NullifyHonkVerifier) over the NULLIFY/1 ABI [first_root,last_root,sequence_commitment,count] -- old-set-root equality (the concurrency rule), count==1, and the proof. This is the historical anti-replay guard on-chain, distinct from TRANSITION/1's batch-local insertion-chain nullifier_root (different representation: TAG_SET sorted-set fold vs TAG_NULLIFIER insertion chain), so no transition circuit/fixture change. EVENT-COMPLETE/1 is NOT wired (4/REG S5: the base registry MUST NOT require it). Real NULLIFY/1 keccak-oracle proof verifies on-chain in forge; stale set root / tampered proof / count!=1 refused.
  source: candidates/cand-0023-nullify-registry/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0023-nullify-registry/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0023-NULLIFY-REGISTRY-2026-06-13.md
```
