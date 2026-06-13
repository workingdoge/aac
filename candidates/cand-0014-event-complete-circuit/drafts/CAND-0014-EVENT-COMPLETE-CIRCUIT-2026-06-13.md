# cand-0014-event-complete-circuit (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0014-event-complete-circuit-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: The EVENT-COMPLETE/1 circuit at circuits/event-complete: takes the typed event as private witness, runs Phi_R in-circuit (rulebook crate), and binds journal_commitment to the COMPILED journal — so the proof attests journal_commitment commits to Phi_R(event), a P^n zero-account, not an arbitrary balanced journal. Realizes obligations 4+5+10. Includes making rulebook's struct fields pub for cross-crate use. Proven end-to-end on arm64 macOS (bb verify ok, 14,348 gates); negative tests reject a journal commitment from a different event and a tampered event commitment.
  source: candidates/cand-0014-event-complete-circuit/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0014-event-complete-circuit/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0014-EVENT-COMPLETE-CIRCUIT-2026-06-13.md
```
