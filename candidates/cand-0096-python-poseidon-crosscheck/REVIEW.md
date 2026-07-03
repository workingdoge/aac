```
ReviewJudgment:
  candidate_id: cand-0096-python-poseidon-crosscheck
  reviewed_at: 2026-07-03T18:00:00Z
  subject:
    brief_sha256: 64a36bf03b252b4246cd80b416dc40b57d723a58da26c4c3a7e29fbbaaf08b03
    landing_tier: normal
    review_prompt_sha256: c5bbfe132864e64d71aec174646311eac427c67285a80c2343cc1cb9d0b2f411
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0096-python-poseidon-crosscheck . -> REPRODUCED (pass attested, pass reproduced, evidence intact)"
  findings: none
  recommendation: admit
```

```
ReviewNote:
  candidate_id: cand-0096-python-poseidon-crosscheck
  reviewed_at: 2026-07-03T18:00:00Z
  brief_audited: agree - the 4-item cargo list in BRIEF.md matches the actual seeds tree (pedersen_vector_1.py NEW at 738 lines; PEDERSEN-VECTOR-1.md +8/-3; PEDERSEN-VECTOR-1.json +2/-2; QUEUE.md +2/-2).
  claims_verified:
    - claim=pedersen_vector_1.py is independent and dependency-free; evidence=seeds/sites/ledger/specs/profiles/reference/pedersen_vector_1.py:1-738 imports only argparse/json/sys/pathlib/typing; grep for subprocess/nargo/barretenberg/requests/urllib/socket returned nothing; poseidon2 implemented in-file (sbox x^5, matrix_multiplication_4x4, internal_m_multiplication, R_F=8+R_P=56); verdict=verified.
    - claim=Python re-derivation byte-matches vectors/PEDERSEN-VECTOR-1.json; evidence=reviewer-run "python3 seeds/.../pedersen_vector_1.py check seeds/.../PEDERSEN-VECTOR-1.json" printed "match" rc=0; verdict=reproduced.
    - claim=tampered round constant fails because derived points change (not trivial assert); evidence=--tamper-round-constant produced "first byte mismatch at offset 1899" rc=1; mutated_round_constants() modifies rows[0][0], a real round-0 full constant used by add_round_constants; offset 1899 is deep in derived JSON output; verdict=verified.
    - claim=even-y canonicalization is exercised by G_0, G_1, G_2; evidence=reviewer-run check-even-y printed "even-y canonicalization exercised by generator raw odd sqrt - G_0, G_1, G_2"; verdict=verified.
    - claim=constants provenance; evidence=/nix/store/4rb54wn3b0cydjc5f0n6h3a8xlyw58i0-source exists; shasum poseidon2_constants.rs=4e31415d0696eef3ca558746841a12f54250f452e2b53c35aba96684fb776b3b matches; poseidon2.rs=6511aeb27d28efa0c6e2e69dcf4b50da31e397df9fdffffe6bcdd01e096e5fc9 matches; noir_stdlib/src/hash/mod.nr=2197142a0150aa9e05a9f997bc6e43bd716a96fa875be2bf08ce38b71505aee4 matches; verdict=verified.
    - claim=round constants transcribed correctly; evidence=first four Python words match source INTERNAL_MATRIX_DIAGONAL (10dc6e9c, 0c28145b, 00544b83, 222c0117); spot-checked partial round constants (123106a9, 26e1ba52, 1cb55cad, 1dcd73e4, 10ba3a0e), final full-round rows (1797130f/0a76225d/1fffb9ec/25721c4f and 17656347...) - all match; zero-padding of partial rounds matches Python's zero rows in cols 1-3; verdict=verified.
    - claim=honesty clause upgrade accurate; evidence=diff replaces "not yet an independent Poseidon2 implementation cross-check" with wording scoped to implementation independence only (does not claim independent-constants derivation); verdict=verified no overclaim.
    - claim=queue update well-formed; evidence=candidates/QUEUE.md removes [open] cand-0093 follow-up line and adds [resolved cand-0096-python-poseidon-crosscheck, 2026-07-03] entry with accurate synopsis; verdict=verified.
    - claim=attested evidence reproduces; evidence=eval-check REPRODUCED with pass attested, pass reproduced, evidence intact, attestation f15f4fc1fdb5 verified before and after re-run; verdict=verified.
  concerns: none
  questions_asked: none (non-interactive convening; coordinator context-notes 1-6 all verified above)
  recommendation: admit
```
