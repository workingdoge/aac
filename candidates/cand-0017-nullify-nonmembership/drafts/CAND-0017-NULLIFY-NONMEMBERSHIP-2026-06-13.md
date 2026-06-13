# cand-0017-nullify-nonmembership (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0017-nullify-nonmembership-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: NULLIFY/1 (3/PROOF S4.2) at circuits/nullify: prove non-membership + insertion into the consumed-nullifier set via the indexed low-leaf range bracket over a strictly-sorted invariant (Field ordering by bn254::lt) — the historical-set anti-replay guard. ABI [first_root,last_root,sequence_commitment,count]. Composition: consumes a fresh EVENT-COMPLETE/1 event_nullifier and REJECTS replaying a spent one. Proven end-to-end on macOS (bb verify ok). Bound: one insertion, sorted-array fold root; production = binary indexed Merkle with succinct path proofs.
  source: candidates/cand-0017-nullify-nonmembership/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0017-nullify-nonmembership/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0017-NULLIFY-NONMEMBERSHIP-2026-06-13.md
```
