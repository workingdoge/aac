# cand-0008-bvr-clearing-kernel (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0008-bvr-clearing-kernel-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: A non-normative design note at sites/ledger/design/ — the BalancedVectorReceipt / P^n Clearing Kernel: a proof-carrying 2/FACT Event whose private witness compiles (via the canonical rulebook Phi_R) to a P^n transaction zero-account. Records the layered architecture (2/FACT Event -> Phi_R compiler -> BVR/1 application target -> TRANSITION/1 enshrined -> 5/NET -> VNET/1), the doctrine that Phi_R schema-completeness is an APPLICATION target (not enshrined; registry refuses unbalanced state, application targets refuse incomplete receipts, evidence layers grade truth), the separation of VNET/1 (amount-vector netting over P^n via per-dimension Pedersen generators) from 5/NET (fact-occurrence netting over Z[X]), and the in-circuit Poseidon2 vs deliberate homomorphic Pedersen-commitment hash split. Non-normative: informs future 9/PROV/10/ADMIT/12/OTC work, takes no RFC number yet.
  source: candidates/cand-0008-bvr-clearing-kernel/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0008-bvr-clearing-kernel/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0008-BVR-CLEARING-KERNEL-2026-06-13.md
```
