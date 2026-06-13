# cand-0021-review-findings (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0021-review-findings-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Remediate the post-compaction review findings (P1/P2/P3). P2: NULLIFY/1 must refuse new_value==0 (the empty-slot sentinel TRANSITION/1 reserves) with a negative test; also assert the EVENT-COMPLETE/1 nullifier is nonzero. P3: add a before-first (low_index=0) ACCEPT test so cand-0017's before-first evidence claim is witnessed, plus a correction note on cand-0017. P1: narrow EVENT-COMPLETE/1's obligation-9 claim to an event-scoped one-shot nullifier (H over rulebook+event+parties), NOT the 2/FACT S3 factId-derived nullifier set (cjson-in-circuit unimplemented) -- in the circuit comments and the EVENT-COMPLETE-1.md spec.
  source: candidates/cand-0021-review-findings/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0021-review-findings/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0021-REVIEW-FINDINGS-2026-06-13.md
```
