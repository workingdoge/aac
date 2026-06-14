# cand-0040-repo-clearing (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0040-repo-clearing-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Add the first REAL clearing instrument on the EVENT/1 harness: a FICC/GSD repurchase agreement (repo), modeled as the clearing kernel sees it. New app lib circuits/repo compiles BOTH legs -- OPEN (borrower delivers collateral, receives principal cash) and CLOSE (borrower returns principal+repo-interest, lender returns collateral) -- each a per-dimension zero-account over basis B=2 {cash, security par}: a leg merely TRANSFERS cash one way and securities the other, so balance is a theorem for any quantities. The repo INTEREST is the cash DELTA between legs (close cash = open cash + interest), not a within-leg imbalance. Two bins event-repo-open + event-repo-close prove each leg end-to-end via the IDENTICAL discharge call (distinct R1 tags 127/128). DOCTRINE: collateral par and cash cents are SEPARATE incommensurable dimensions; the haircut/valuation (collateral value = principal/(1-haircut)) is a pricing relationship OUTSIDE the zero-account -- vector Pacioli conserves the par, not the fluctuating value (1/PACI Ellerman). Cross-leg sequencing (close consumes the open position) is a TRANSITION/1 concern, and the multilateral net of many such legs is VNET/1's -- both deliberately OUT of scope here (no VNET files touched). App-side only: kernel boundary law holds. Witnessed: nargo test --workspace green (repo 3/3 incl. legs_link + event_repo_open 5/5 + event_repo_close 4/4 + existing crates value-preserving), both repo witnesses solve, kernel-boundary-check clean, R1 tags 127/128 recorded.
  source: candidates/cand-0040-repo-clearing/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0040-repo-clearing/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0040-REPO-CLEARING-2026-06-14.md
```
