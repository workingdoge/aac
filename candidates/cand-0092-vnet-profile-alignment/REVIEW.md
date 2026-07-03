```
ReviewJudgment:
  candidate_id: cand-0092-vnet-profile-alignment
  reviewed_at: 2026-07-03T14:00:10Z
  subject:
    brief_sha256: d0af19a6170c8306dd996f8a08009e44926ccd553650d63a84fdff64e76f58f5
    landing_tier: normal
    review_prompt_sha256: d9a753207c60c09b5734524a21a03c0f6d20f8b07a96f1b7c90e11547a179266
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0092-vnet-profile-alignment . -> attested pass, fresh-run pass, evidence restored byte-exact"
  findings: none
  recommendation: admit
```

```
ReviewNote:
  candidate_id: cand-0092-vnet-profile-alignment
  reviewed_at: 2026-07-03T14:00:10Z
  brief_audited: |
    Agree. The brief is honest about what lands: only a two-line addition to
    `candidates/QUEUE.md` recording an obstruction. No cargo touches
    `world-app/provekit-vnet`, no cargo touches the spec, no cargo touches
    the live circuit. The witnessed delta ("record the blocker instead of
    silently choosing soundness-critical generators") matches the seed diff:
    a single new open queue item citing PEDERSEN-VECTOR/1 §2 and pointing at
    the missing conformance vector under
    `sites/ledger/specs/profiles/vectors/`.
  claims_verified:
    - claim: "PEDERSEN-VECTOR/1 §2 seed uses strings the profile never encodes to Field."
      evidence: sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md:52-57
      verdict: |
        Verified. The seed is
        `Poseidon2("aac/vnet/1", profile_id, basis_commitment, basis_type_id_j, label, j)`
        and `try_increment` reads `x = Poseidon2(s, ctr)` — Poseidon2 permutes
        Field elements, but the profile does not define how the string literals
        "aac/vnet/1", "G", "H" or the `profile_id`/`basis_type_id_j` identifiers
        are encoded to Field. Compare
        sites/ledger/specs/profiles/VNET-BN254-G1-1.md:56-67, which pins an
        explicit canonical-JSON UTF-8 encoding and a SHA-256 counter rule for
        BN254. The Grumpkin profile has no analogue.
    - claim: "`basis_commitment` formula is not fixed for this profile."
      evidence: sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md:53, sites/ledger/specs/profiles/VNET-BN254-G1-1.md:74-86, sites/ledger/specs/applications/VNET-1.md:67,113-114
      verdict: |
        Verified. `basis_commitment` appears inside the seed input but no
        formula is stated for the Grumpkin/PEDERSEN-VECTOR profile. VNET-1.md
        treats it as an opaque scalar public input. The BN254 profile
        explicitly defines it (SHA-256 over `["aac/vnet-bn254-g1/1/basis",
        profile_id, basis_type_ids]` mod r); no such formula exists here.
    - claim: "Canonical-y rule is undefined."
      evidence: sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md:59-62, sites/ledger/specs/profiles/VNET-BN254-G1-1.md:65-67
      verdict: |
        Verified. PEDERSEN-VECTOR/1 says "canonically-signed y" without
        selecting a rule; the BN254 profile picks "even y, else p - y". Under
        the Grumpkin profile as written, prover and verifier could deterministic-
        ally derive different `y` for the same `x` and still both call it
        canonical, which is exactly the pinning gap the candidate calls out.
    - claim: "No Grumpkin conformance vector or reference generator."
      evidence: sites/ledger/specs/profiles/vectors/ (listing shows only VNET-BN254-G1-1.json), sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md:147-161
      verdict: |
        Verified. §7 mandates accept/reject vectors including a mismatched-
        generator-set rejection, but the vectors directory contains only the
        BN254 fixture. There is no PEDERSEN-VECTOR/1 Grumpkin reference vector.
    - claim: "Live circuit still uses the old free-label derivation."
      evidence: world-app/provekit-vnet/src/main.nr:27
      verdict: |
        Verified. `std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0)`
        is not basis-bound (no `basis_commitment` / `basis_type_id_j` mixed in)
        and thus cannot satisfy PEDERSEN-VECTOR/1 §2 as written. Aligning the
        circuit today would require the candidate to pick constants for all
        four gaps above.
    - claim: "Evaluator harness attests pass and reproduces pass."
      evidence: bash tools/eval/eval-check.sh candidates/cand-0092-vnet-profile-alignment .
      verdict: |
        Reproduced. Attestation `b3b4349c3119…` verifies; snapshot re-run
        emits pass; evidence restored byte-exact; final line
        "REPRODUCED (pass attested, pass reproduced, evidence intact)".
  concerns: none
  questions_asked:
    - question: |
        Are the four claimed spec gaps real, or already resolved elsewhere in
        the spec suite (VNET-1.md, 3/PROOF)?
      answer: |
        All four are real. I read PEDERSEN-VECTOR-1.md end-to-end and cross-
        checked VNET-1.md §2/§3/§5 and VNET-BN254-G1-1.md §3/§4. VNET-1.md
        deliberately leaves the group, encoding, and generator rule to the
        profile (§2 line 42). The BN254 profile answers each of the four
        questions in a way that would not port to Grumpkin/Poseidon2 without
        editorial choice. Nothing in 3/PROOF or VNET-1.md pins string-to-Field,
        `basis_commitment` for this profile, or the canonical-y rule.
    - question: |
        Is the queue entry precise enough to scope a follow-up candidate?
      answer: |
        Yes. The new queue line names the exact §2 clauses that are
        underspecified, the missing artifact (`sites/ledger/specs/profiles/
        vectors/` Grumpkin fixture), the required vector set (accept +
        mismatched-generator reject + old-free-label reject), and offers the
        alternative branch: "amend the profile to explicitly adopt a precise
        Noir builtin derivation with verifier re-derivation semantics." A
        spec-completion candidate can be scoped directly off that entry.
    - question: |
        Was refusing to pick constants correct under the profile as written?
      answer: |
        Yes. §2 makes generators "verifier-determined, not prover-chosen" and
        forbids witnessed generators on soundness grounds (a known DL relation
        would forge a zero opening). Silently choosing string-to-Field,
        `basis_commitment`, or canonical-y in the circuit would either
        contradict the not-yet-written spec or force the spec to conform to an
        already-shipped circuit — the opposite of the profile's rule that
        generator derivation is part of target identity (§8). Recording the
        obstruction is the profile-respecting move.
  recommendation: admit
```
