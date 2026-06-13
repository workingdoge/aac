# cand-0019-registry-deployable (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0019-registry-deployable-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: Make the 4/REG registry actually deployable: the bb HonkVerifier is 24,644B runtime (68 over EIP-170) at optimizer_runs=200 — drop to 50 (23,782B, 794 under) so it deploys on a real EVM, correctness unchanged (forge test still green). Add registry/script/Deploy.s.sol (deploys the verifier + auto-links its ZKTranscriptLib + the Registry pinned to it); verified deploying to live anvil under EIP-170 (ONCHAIN EXECUTION SUCCESSFUL).
  source: candidates/cand-0019-registry-deployable/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0019-registry-deployable/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0019-REGISTRY-DEPLOYABLE-2026-06-13.md
```
