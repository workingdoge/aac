# cand-0039-second-posting-program (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0039-second-posting-program-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Add a SECOND posting program to validate that the cand-0037 EVENT/1 harness (circuits/event-harness) is genuinely schema-agnostic, not accidentally fit to goods-receipt-invoice. New app lib circuits/bom-receipt compiles a bill-of-materials / materials-kit receipt (a garment maker buys fabric+thread+trim from a supplier against USD) over basis B=4 with DENSE debit/credit vectors -- vs rulebook's B=3 single-good trade -- so discharge<R,B> is exercised at a different B and journal shape with the IDENTICAL harness glue. New bin circuits/event-bom-receipt is a near-clone of event-complete differing ONLY in the schema-specific half (4-quantity Event, its event_commitment at a distinct R1 tag 126, Phi_P with B=4); the schema-agnostic obligations route through the same discharge call. DOCTRINE: a kit RECEIPT (exchange), not an assembly TRANSFORM -- the harness requires a per-dimension zero-account, which an exchange (each good conserved, cash the other way) satisfies but a transform (incommensurable inputs -> different output) cannot (1/PACI Ellerman vector Pacioli). App-side only: kernel boundary law holds. Witnessed: nargo test --workspace green (bom_receipt 2/2 + event_bom_receipt 6/6 incl. a B=4 unbalanced-journal rejection + the existing crates value-preserving), event_bom_receipt witness solves, kernel-boundary-check clean, R1 tag 126 recorded.
  source: candidates/cand-0039-second-posting-program/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0039-second-posting-program/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0039-SECOND-POSTING-PROGRAM-2026-06-14.md
```
