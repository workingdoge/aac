```text
ReviewJudgment:
  candidate_id: cand-0090-lineage-reconciliation-record
  reviewed_at: 2026-07-03T06:30:00Z
  subject:
    brief_sha256: 16e1ab657057f78f798ec420f01ba541402af53ef31fbfee8f4eac5672afd804
    landing_tier: normal
    review_prompt_sha256: 670d871cc15ce769f8a10615ef3551c041d517ad2f683a04d3671570e7b70131
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0090-lineage-reconciliation-record . -> attested pass reproduced, evidence restored byte-exact, attestation re-verified (dba059f4f2ef)"
  findings: none
  recommendation: admit
```

```text
ReviewNote:
  candidate_id: cand-0090-lineage-reconciliation-record
  reviewed_at: 2026-07-03T06:30:00Z
  brief_audited: agree — BRIEF.md cargo enumeration matches LANDING and the seed tree; the record layer claim (evidence-tooling, no doctrine change) is accurate, and the seed touches only design docs and the queue.
  claims_verified:
    - "Fork at 713248d -> git log 713248d -> matches (close-out cand-0036-naming-layering) -> pass"
    - "Merge at 2776e4a -> git log 2776e4a -> matches ('Merge remote-tracking branch origin/main') -> pass"
    - "Backup branch backup/pre-reconcile-019a76e tip 019a76e -> git rev-parse -> 019a76ef77...bb0c0 -> pass"
    - "Memory chain repair at 396876c, kernel refresh at f61dbd6, pre-reconciliation commit at 07b1f8f -> git log -> subjects match design-note prose verbatim -> pass"
    - "Dual cand-0037..cand-0044 slug pairs on disk -> ls candidates/ -> all eight number/slug pairs present for both lineages (event-harness/vnet-profile-vectors, provekit-beta19/vnet-link-verifier, ...) -> pass"
    - "Cite-by-slug ambiguity rule -> 0005-lineage-reconciliation-record.md lines 63-65: uniqueness by (number, slug) pair; number-only refs into cand-0037..cand-0044 are ambiguous and must cite the slug -> mechanically applicable -> pass"
    - "Three named follow-ups reach queue seed -> diff candidates/QUEUE.md vs seeds/candidates/QUEUE.md -> three [open] entries dated 2026-07-03 (Atlas registry mirror re-pin, origin push decision, staleness triage) plus one [resolved cand-0090] entry -> pass"
    - "Applications README as second hand-union exception -> 0005-lineage-reconciliation-record.md lines 91-92 states the extra hand-union, keeping remote LEDGER/1 and local NOVATE/1 -> present and factual -> pass"
    - "Tripwire kernel-adaptations claim -> ls tools/schemas/kernel-adaptations.tsv -> absent (no such file), while tools/schemas/instance.tsv still reads cycle_id aac-2026-06-13, instance aac -> soul carve-out phrasing accurate -> pass"
    - "Memory verify 96 records -> bash tools/memory.sh verify -> 'memory: verify ok (96 records)' -> pass"
    - "Queue baseline 21 open + 86 resolved, single Open/Resolved header -> grep counts on live queue -> 21/86 and queue-lint.sh clean; seed extends to 24/87 preserving headers -> pass"
    - "Evidence reproducibility -> tools/eval/eval-check.sh -> attestation verified, snapshot re-run pass, restore byte-exact, attestation re-verified -> pass"
  concerns: none — the record accurately describes commit-visible reconciliation facts, states the number/slug ambiguity rule in a form future workers can apply, seeds all three named follow-ups into the queue, and the two builder fact-corrections (applications README hand-union, kernel-adaptations tripwire absent = soul carve-out) match the on-disk state without hedging. The design note explicitly disclaims informal `boat-refresh --wave --check` phrasing that is not reproducible from this tree, which is the correct honest posture for a record candidate.
  questions_asked: none — non-interactive convening; verification proceeded directly against artifacts.
  recommendation: admit
```
