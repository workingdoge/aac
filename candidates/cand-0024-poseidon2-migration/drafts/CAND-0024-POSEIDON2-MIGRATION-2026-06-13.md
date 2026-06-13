# cand-0024-poseidon2-migration (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0024-poseidon2-migration-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: PERF: migrate the circuits' commitment hash from pedersen_hash to a Poseidon2 sponge (vendored over std::hash::poseidon2_permutation, t=3/rate=2/cap=1, capacity initialized with input length for arity domain-separation -- AAC's own commitment hash, deterministic + collision-resistant, no external value to match). New shared circuits/hash lib; swap all 18 pedersen_hash sites across ledger(4)/rulebook(1)/transition(7)/nullify(6); event-complete + pacioli inherit/unchanged. Commitment VALUES change by design (breaks cand-0016 byte-identity -- the point); the registry fixtures/verifiers + web roots regenerate in follow-ups. Headline: pedersen ~3,586 gates/2:1-hash vs poseidon2_permutation ~75 (~48x) on the pedersen-dominated 40,511-gate transition. Witnessed: nargo test green across the workspace + measured bb gates drop.
  source: candidates/cand-0024-poseidon2-migration/ (META, scores.json, traces/)
  selected_material: TODO-review
  left_behind: TODO-review
  owner: TODO-review
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0024-poseidon2-migration/
  verification_boundary: TODO-review
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0024-POSEIDON2-MIGRATION-2026-06-13.md
```
