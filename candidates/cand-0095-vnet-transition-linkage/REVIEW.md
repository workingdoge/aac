```text
ReviewJudgment:
  candidate_id: cand-0095-vnet-transition-linkage
  reviewed_at: 2026-07-03T15:08:44Z
  subject:
    brief_sha256: 3d196cf17634af7afcaeef7faecab09a1434e40b548d5bdfa8424a603864ed8f
    landing_tier: normal
    review_prompt_sha256: cdbac7bb86a6f7136104690d0511cd279114a8813583637d766285f7cbcdc772
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0095-vnet-transition-linkage . -> REPRODUCED (pass attested, pass reproduced, evidence intact)"
  findings: none
  recommendation: admit
```

```text
ReviewNote:
  candidate_id: cand-0095-vnet-transition-linkage
  reviewed_at: 2026-07-03T15:08:44Z
  brief_audited: >-
    agree. BRIEF.md accurately enumerates the four-file cargo (world-app/provekit-vnet/{src/main.nr,
    README.md, Prover.toml.example} plus candidates/QUEUE.md), the pinned toolchain
    (nixpkgs_rev=ac62194c3917), and evaluator verdict pass. The witnessed delta ("VNET/1 section 4.1
    TRANSITION/1 journal linkage") matches what actually lands in seeds/.
  claims_verified: >-
    (1) Tautology absent -> seeds/world-app/provekit-vnet/src/main.nr:262 asserts
    context_commitment_pub == SAMPLE_CONTEXT_COMMITMENT (constant 9001, line 20), not a self-equality;
    positive test rejects_wrong_context_commitment covers the check (main.nr:671). Verdict: pass.
    (2) Linkage constraint present -> assert_transition_linkage at main.nr:116-147 recomputes the
    canonical TAG_JOURNAL=3 row fold and enforces the per-basis debit/credit sum equalities; called
    per atom from main.nr:282. Verdict: pass.
    (3) Cross-toolchain byte-agreement of the linkage recomputation -> the beta.19 fold in
    transition_journal_commitment (seeds/.../main.nr:96-114) is structurally identical to
    circuits/ledger/src/lib.nr:15-33 (beta.14 kernel journal_commitment): same TAG_JOURNAL=3, same
    seed hash([TAG_JOURNAL, 0]), same per-row buf layout [tag, jc, account, debits[0..B],
    credits[0..B]], and the beta.19 hash.nr (world-app/provekit-vnet/src/hash.nr) is the same
    Poseidon2 sponge (t=4, rate=3, capacity=length) as circuits/hash/src/lib.nr:23-35. Because both
    call std::hash::poseidon2_permutation, digests agree byte-for-byte for identical input rows.
    Verdict: pass.
    (4) Negative test rejects_mismatched_transition_link fires at the linkage assert specifically
    -> traces/t03-nargo-test-positive.out shows the test passes with expected message
    "TRANSITION/1 journal commitment does not bind atom vector"; traces/t03-nargo-test-mutant.out
    shows the same test fails ("wrong message ... Got: commitment_set_commitment does not fold
    recomputed points") when the linkage assert is removed, i.e. the check that catches the mutated
    jcs[0]+=1 is uniquely the linkage assert, not the downstream commitment_set fold. Verdict: pass.
    (5) Queue update -> seeds/candidates/QUEUE.md line 54 adds resolved cand-0095 entry, line 56
    amends the resolved cand-0094 entry to record that its section 4.1 deferral was closed; the live
    QUEUE.md line 46 [open] cand-0094-followup placeholder is superseded by the new resolved line
    54. Verdict: pass.
    (6) Attestation -> tools/eval/eval-check.sh reproduced the pass verdict, restored evidence
    byte-exact, and re-verified attestation 0a21ec9f3f3b (matching scores.json.provenance.attestation).
    Verdict: pass.
  concerns: >-
    Coordinator asked whether SAMPLE_CONTEXT_COMMITMENT=9001 is honest demo scope or a placeholder
    that merely defeats the tautology probe. VNET-1.md section 5 marks context_commitment as
    "unconstrained; deployment/epoch/policy context" and section 6 requires the verifier to
    check it against policy context off-circuit -- i.e. the spec explicitly intends context meaning
    to come from the policy verifier, not from an in-circuit recomputation. Pinning to a named
    SAMPLE_CONTEXT_COMMITMENT is architecturally analogous to pinning BASIS_COMMITMENT (which is
    also verifier-derived per PEDERSEN-VECTOR/1). The seed README (world-app/provekit-vnet/README.md
    lines 86-87) documents the choice as "this demo instance's pinned sample context value (9001),
    replacing the former ABI-slot self-check" -- honest scoping. Not a finding, but noting that the
    load-bearing meaning still lives entirely at the off-circuit policy verifier; a production
    deployment must supply a real context_commitment from policy before this instance is admissible.
  questions_asked: >-
    Non-interactive convening; coordinator posed four questions, addressed above:
    (a) context-binding intent -> spec marks context_commitment unconstrained; SAMPLE_ constant is
    honest demo scope, explicitly documented as such in the seed README; not a finding.
    (b) linkage byte-agreement -> confirmed by direct code comparison between
    seeds/.../main.nr:96-114 and circuits/ledger/src/lib.nr:15-33; identical construction over the
    same Poseidon2 permutation.
    (c) negative test locus -> trace evidence (t03 mutant) shows the linkage assert is precisely the
    check that rejects the tampered jcs; without it, the downstream commitment_set check catches a
    different message.
    (d) queue update accuracy -> confirmed on both the new resolved cand-0095 line and the amended
    cand-0094 acknowledgement.
  recommendation: admit
```
