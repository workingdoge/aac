# cand-0015-event-complete-roles-nullifier (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0015-event-complete-roles-nullifier-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Grow the EVENT-COMPLETE/1 circuit toward a complete BVR: add role coverage (obligation 2 — Buyer and Supplier present + distinct, participant_set commitment) and the event_nullifier (obligation 9 — one-shot identity H(rulebook, event, parties) derived in-circuit so a replay cannot use a fresh nullifier). Negative tests reject self-dealing, a missing role, and a foreign nullifier; the nullifier is shown event/party/rulebook-distinguishing. Proven end-to-end on macOS (bb verify ok).
  source: candidates/cand-0015-event-complete-roles-nullifier/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0015-event-complete-roles-nullifier/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0015-EVENT-COMPLETE-ROLES-NULLIFIER-2026-06-13.md
```
