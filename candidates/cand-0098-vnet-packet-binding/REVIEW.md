```ReviewJudgment
ReviewJudgment:
  candidate_id: cand-0098-vnet-packet-binding
  reviewed_at: 2026-07-03T23:34:22Z
  subject:
    brief_sha256: eca7eece648406b68ae1b45d77f8a00cdb6ad67d8e21756ef99fb046dfb84008
    landing_tier: normal
    review_prompt_sha256: 54f94e08dcb2e45c183d1580d5c17ee97447396d110658b014cbbd3d9e80c63a
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: bash tools/eval/eval-check.sh candidates/cand-0098-vnet-packet-binding . -> REPRODUCED (pass attested, pass reproduced, evidence intact); attest verified 41b40fe78418
  findings: none
  recommendation: admit
```

```ReviewNote
ReviewNote:
  candidate_id: cand-0098-vnet-packet-binding
  reviewed_at: 2026-07-03T23:34:22Z
  brief_audited: agree - cargo enumeration in BRIEF.md matches LANDING (seeds/fundraise-demo-runner/src/{index.mjs,index.d.ts,vnet-provekit-binding.mjs}, test/run-tests.mjs, README.md, seeds/QUEUE.md queue-merge). VALIDATE.json is admitted with witness_refs over DECLARATION/LANDING/META/QUEUE.base. scores.json + traces attested (41b40fe78418) and re-verified by eval-check.
  claims_verified:
    - claim: "static example-copy path is dead" -> seeds/fundraise-demo-runner/src/index.mjs:2058-2062 writes vnetWitness prover_toml (or a packet-bound placeholder) into Prover.toml and Prover.toml is included in the shouldCopyCircuitPath skip-list (index.mjs:2085); vnet-provekit-binding.mjs:364-376 renders TOML from packet.vnet_link witness fields. eval-self.sh:150-163 mutates by appending a cp(Prover.toml.example, Prover.toml) line and rejects the mutant. Verdict: verified.
    - claim: "packet.vnet_link -> Prover.toml mapping is total on constrained fields" -> vnet-provekit-binding.mjs:52-102,168-230 rejects with typed reasons: profile_id_mismatch, basis_mismatch, basis_commitment_mismatch, atom_count_mismatch, transition_ref/journal_commitment parseField, transition witness missing/row-count mismatch, transition_account bound (<N_ACCT), coordinate bound (MAX_COORD), debit/credit vs transition sums, r_debit/r_credit parseField, and Grumpkin-recomputed debit/credit commitments checked against declared points on-curve. Aggregate opening (msm over commitments) checked against declared value; assertZeroNet enforces basis-wise net==0. Verdict: verified.
    - claim: "no silent defaults on constrained fields" -> mostly verified with one caveat: normalizeContextCommitment (vnet-provekit-binding.mjs:297-307) applies a fallback SAMPLE_CONTEXT_COMMITMENT (9001) when both vnet.context_commitment and vnet.circuit_context_commitment are absent, then requires the resolved field to equal 9001. Because 9001 is a fixed public input of the cand-0095 demo circuit and the check-then-fail semantics only accept 9001, this cannot admit an unrelated context; it is a silent alias (missing == 9001) rather than a soundness gap. Worth noting for follow-on but not disqualifying.
    - claim: "tamper refusal fires PRE-prove for atom-mismatch" -> eval-self.sh:237-256 sets packet.vnet_link.vnet.atoms[0].debit[0] = 101 and requires error.reason === vnet_provekit_atom_debit_mismatch; probe returns 42 on that exact reason. Cross-checked against normalizeAtom debit-vs-transition-sum check (vnet-provekit-binding.mjs:222-224). Traces t02-public-input-correspondence.out records "amount-tampered packet refused before proving". Verdict: verified.
    - claim: "fundraise fixture shape mismatch fails closed" -> eval-self.sh:259-278 loads the live FUNDRAISE-DEMO-1 packet (four-atom vnet-bn254-g1/1 USDC/SAFE fixture) and requires error.reason === vnet_provekit_profile_mismatch; probe returns 43 on that reason. README.md:16-23 documents the refusal and QUEUE.md open entry (line 12) queues the follow-on fundraise-shaped circuit/profile work. Verdict: verified.
    - claim: "require_live_proof semantics honest" -> index.mjs:1066 still sets require_live_proof: true in the workflow policy and index.mjs:185-208 (bindProveKitVnetWitnessToVerifierReceipt) enforces publicInputsCommitment === witness.public_inputs_commitment and core.packet_commitment === packetCommitment(packet) before returning. README.md:28-29 states require_live_proof: true is no longer satisfied by a proof over data unrelated to the packet. Combined with the shape-mismatch refusal, the flag is preserved with strengthened meaning. Verdict: verified.
    - claim: "receipt carries both digests with pre-prove correspondence check" -> index.mjs:185-209 records packet_binding_schema, packet_public_inputs_commitment, packet_vnet_link_commitment, vnet_circuit_public_inputs_commitment, vnet_witness_commitment, prover_toml_digest, and a fresh receipt_digest bound over the new fields. The prover receives work.vnet_witness?.public_inputs (index.mjs:127) rather than raw packet.public_inputs, closing the loop. eval-self.sh:280-339 tests a delete-field mutant (delete mutant.packet_vnet_link_commitment) and returns 44 on rejection. Traces t04 confirms. Verdict: verified.
    - claim: "queue-merge lands the follow-on" -> LANDING has seeds/QUEUE.md TAB candidates/QUEUE.md TAB queue-merge; eval-self.sh:363-391 runs queue-lint on the merged QUEUE and rejects both a LANDING-without-queue-merge mutant and a duplicate-header QUEUE mutant. Positive prose verified in seeds/QUEUE.md. Verdict: verified.
    - claim: "attested evidence reproduces byte-exact" -> bash tools/eval/eval-check.sh candidates/cand-0098-vnet-packet-binding . -> attestation 41b40fe78418 verified pre and post re-run; evidence restored byte-exact; fresh run verdict pass rc=0. Verdict: verified.
  concerns:
    - The context_commitment fallback to SAMPLE_CONTEXT_COMMITMENT (9001) when both fields are absent is a silent alias. It is currently benign because the circuit fixes context_commitment_pub = 9001 and mismatched values are rejected, but a future circuit/profile with a variable context should require the field explicitly rather than defaulting. Not disqualifying for admit.
    - Shape-mismatch fail-closed means the runner cannot currently produce a live receipt for the canonical FUNDRAISE-DEMO-1 fixture end-to-end. This is honestly documented (README, QUEUE) and is the correct trade-off for closing the P1 static-witness bypass; the follow-on candidate is queued.
  questions_asked: none - reviewer convened non-interactively; open concerns recorded above.
  recommendation: admit
```
