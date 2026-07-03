```
ReviewJudgment:
  candidate_id: cand-0094-vnet-circuit-profile-conformance
  reviewed_at: 2026-07-03T14:50:42Z
  subject:
    brief_sha256: cfcf6470e3be362316679dcc1bdadfe2fb6d7daa3b10d4e30c199af0d19f07f4
    landing_tier: normal
    review_prompt_sha256: b34251302311c0921aeea55d972cb4f5bd08e99c357f3207e55f2b3895d74c7f
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0094-vnet-circuit-profile-conformance . -> REPRODUCED (pass attested 711c97cb7ff8, pass reproduced, evidence restored byte-exact)"
  findings: none
  recommendation: admit
```

```
ReviewNote:
  candidate_id: cand-0094-vnet-circuit-profile-conformance
  reviewed_at: 2026-07-03T14:50:42Z
  brief_audited: agree — the cargo list (main.nr +415/-57, README +42/-16, Prover.toml.example +15/-11, QUEUE.md +3/-1) matches the seed/live diff I inspected; ATTESTED verdict pass reproduces via eval-check.
  claims_verified:
    - "10 pinned generator constants (PROFILE_ID, BASIS_COMMITMENT, H_X/Y, G0_X/Y, G1_X/Y, G2_X/Y) in seeds/world-app/provekit-vnet/src/main.nr:15-32 -> byte-for-byte match against sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json (profile_id field, basis_commitment.field, generators[0..3].point.x/y) -> verdict pass"
    - "profile_id_pub / basis_commitment_pub / atom_count_pub asserted against pinned constants at main.nr:204-209; assert_generator_constants_on_curve() at main.nr:211 checks H and G0..G2 against Grumpkin equation y^2 = x^3 - 17 with the correct base_field -> verdict pass"
    - "per-basis-dimension netting: main.nr:243-249 sums (debit[i][j] as Field - credit[i][j] as Field) over N_ATOMS and asserts == 0 per j. With MAX_COORD=1e12 and N_ATOMS=2, |true integer sum| <= 4e12 << BN254 p ~ 2^254, so Field-zero cannot wrap; the check is exact -> verdict pass"
    - "aggregate opening binding: c_debit[i], c_credit[i] are recomputed inside the circuit via commit(gs, h, ...) using the pinned generators (main.nr:233-234), then commitment_set_commitment_pub is asserted to fold the recomputed points (main.nr:237-241) and aggregate_opening_x/y_pub are asserted to equal aggregate_opening(c_debit,c_credit) (main.nr:251-254); blinding_opening equality (main.nr:256-257) is an additional MSM soundness anchor. Witnessed opening points are on-curve by MSM construction, so no explicit curve check on them is needed -> verdict pass"
    - "negative test rejects_commitment_set_from_legacy_free_label_generators (main.nr:585-615) computes old_commitment_set with prover-supplied legacy-generator points (OLD_C_DEBIT/CREDIT constants) but the witness still forces recomputation with pinned generators, so the fold-mismatch is the right rejection reason; confirmed by traces/t04-nargo-test-positive.out line 21 showing this test failing with the exact `commitment_set_commitment does not fold recomputed points` assert -> verdict pass"
    - "deferred TRANSITION/1 section 4.1 linkage recorded in QUEUE diff: new open entry (seeds/candidates/QUEUE.md:46) explicitly says cand-0094 'deliberately does not claim the full VNET/1 section 4.1 transition-link relation' and names the remaining work (recompute journal_commitment in-circuit or verify a companion link proof) -> verdict pass"
    - "ABI rename context_commitment_pub and ASCII normalization: cosmetic and consistent with the VNET/1 section 5 public surface -> verdict pass"
  concerns:
    - "main.nr:210 asserts `context_commitment_pub == context_commitment_pub` (tautology). This is consistent with the queue's deferred VNET/1 section 4.1 linkage — the slot is held open in the public ABI but binds nothing yet. It is honest given the queue update, but reviewers of the follow-up candidate should verify the real binding replaces this tautology rather than being added alongside it."
    - "The R1CS compiler MSM-only rule (from cand-0044) is respected here: aggregation uses multi_scalar_mul with unit scalars; no EmbeddedCurveAdd. Not a finding, just noting the compatibility."
  questions_asked: none — non-interactive convening
  recommendation: admit
```
