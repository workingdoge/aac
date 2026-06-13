# cand-0016-ledger-composition (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0016-ledger-composition-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Lift a shared circuits/ledger lib (canonical journal_commitment + participant_set + event_nullifier) so EVENT-COMPLETE/1 and TRANSITION/1 COMPOSE on one commitment: TRANSITION/1's journal_commitment is unchanged (byte-identical, lifted verbatim), EVENT-COMPLETE/1 adopts the canonical form, and a composition test shows TRANSITION/1 posts exactly the journal_commitment the BVR certifies (0x014292…) and consumes the BVR's event_nullifier. rulebook gains account indices + the schema event_commitment. Proven end-to-end on macOS.
  source: candidates/cand-0016-ledger-composition/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0016-ledger-composition/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0016-LEDGER-COMPOSITION-2026-06-13.md
```
