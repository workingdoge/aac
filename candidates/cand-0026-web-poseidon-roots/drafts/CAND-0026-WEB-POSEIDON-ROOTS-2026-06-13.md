# cand-0026-web-poseidon-roots (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0026-web-poseidon-roots-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Cascade part 2 (cand-0024): update the web components' hard-coded TRANSITION/1 roots from the old pedersen values to the new Poseidon2 values, so /circuit and /registry display the live proof. aac-transition.ts (prev/next account roots, next nullifier root, journal_commitment, fact_fold, ACIR opcodes 775->673) + aac-row.ts (prev/next account, next nullifier) + circuit.mdx (~775->~673 opcodes). astro build green; new values present, no stale pedersen roots remain.
  source: candidates/cand-0026-web-poseidon-roots/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0026-web-poseidon-roots/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0026-WEB-POSEIDON-ROOTS-2026-06-13.md
```
