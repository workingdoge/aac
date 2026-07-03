# Premath Review Judgments v0

Statement id: `premath.review-judgments.v0`
Owner: Premath (judgment theory: SigPi; record theory:
`premath.record-judgments.v0`)
Status: active for `boat-2026-05-17`

Provenance: boat-native synthesis over landed surfaces only —
`premath.record-judgments.v0` (RJ-1.1/RJ-1.2/RJ-1.5/RJ-1.6),
`premath.check-sigpi-judgment.v0`, PREMATH-0002 BIDIR-4.4 checking
mode, PREMATH-0003 DOCT-9.4 bounded review rounds, and the live
`tools/loop review` prompt discipline. The external maintainability-review
skill discussed during this candidate contributes a review lens only; it
does not board as law.

## Purpose

Boat's review gate currently treats `REVIEW.md` as an independent prose
artifact: the loop can require the file for tier-sensitive cargo and bind
its hash into a decision, but the file itself has no declared record type.
This statement gives `REVIEW.md` its judgment so review history can become
checkable and queryable without erasing the raw reviewer trace.

The first useful improvement is modest:

```text
REVIEW.md exists
```

can later become:

```text
REVIEW.md forms as a ReviewJudgment for this candidate
```

This statement introduces names and obligations, not checking power. A
checker, review-prompt rewrite, historical migration, and review query CLI
are model-layer or evidence-tooling work for later candidates.

## Review Judgment

Law: RVJ-1.1 — Review subject formation. A Boat review judgment is a term
over the current development context:

```text
Gamma_dev,
  c : Candidate,
  b : Brief(c),
  e : EvidencePacket(c),
  l : LandingMap(c),
  p : ReviewPrompt(c)
|- r : ReviewJudgment(c, b, e, l, p)
```

The wire form MUST identify the candidate and bind the reviewed subject by
stable references: `candidate_id`, `reviewed_at`, `brief_sha256`,
`landing_tier`, and the review prompt or convening reference when present.
Missing subject fields fail formation with `record-formation-incomplete`;
out-of-vocabulary subject atoms fail with `vocabulary-atom-failure`.

Law: RVJ-1.2 — Independence and write-scope are typed claims, not proofs.
A review judgment MUST carry reviewer-side claims for fresh-session
independence and write scope, but those claims are checking-mode artifacts
under BIDIR-4.4. In v0, the type requires the claims to be present; it does NOT prove that the reviewer was actually isolated, that no ambient context was shared, or that no file except `REVIEW.md` was written. A consumer that treats the independence claim itself as proof of session isolation commits
`verifier_contract_violation`.

Law: RVJ-1.3 — Evidence audit. A review judgment MUST classify the evidence
audit with the vocabulary:

```text
reproduced | failed | not-run-with-reason | not-applicable
```

For candidates with `scores.json`, the safe rerun witness is
`tools/eval/eval-check.sh CAND_DIR ROOT`; a direct reviewer rerun of
`eval-self.sh` is review evidence only if explicitly classified as unsafe
or clobbering-risk and does not replace `eval-check`. A review that claims
evidence reproduction without citing a reproducible witness is malformed
for this judgment family.

Law: RVJ-1.4 — Findings are typed obligations. Each review finding is a
checking-mode obligation record:

```text
id : FindingId
class : ReviewFindingClassVocab
severity : ReviewFindingSeverityVocab
status : ReviewFindingStatusVocab
subject_ref : path | law_ref | trace_ref | none-with-reason
problem : Prose
required_change : Prose | none
```

The v0 `ReviewFindingClassVocab` is:

```text
evidence
correctness
tier-guard
structural-quality
boundary
test-gap
operator-held
security
docs
maintainability
```

The v0 `ReviewFindingSeverityVocab` is:

```text
blocker | transform | queue | note
```

The v0 `ReviewFindingStatusVocab` is:

```text
open | resolved | superseded | queued
```

Findings preserve reviewer prose; the typed fields are an index and a gate
surface, not a replacement for explanation.

Law: RVJ-1.5 — Recommendation formation. A review recommendation is one of:

```text
admit | transform | deny | needs-more-evidence
```

`admit` is well-formed only when the review carries no open `blocker` or
`transform` finding and the evidence audit is not `failed`.
`transform`, `deny`, and `needs-more-evidence` MUST carry at least one open
finding or a concrete evidence-audit failure. These are formation rules for
the review judgment; the operator or agent decision remains a separate Boat
decision bound by the brief and tier guard.

Law: RVJ-1.6 — Wire honesty and queryability. The statement is the type;
`REVIEW.md` is the wire representation. A future `REVIEW.json`, schema file,
or query index is a compiled artifact of this statement, never executable authority. The raw review prose and referenced traces remain part of the
diagnostic record. Query surfaces may retrieve review history by candidate,
file, law reference, finding class, severity, status, recommendation, and
transform outcome, but a query result MUST NOT authorize admission, landing,
or rollback.

## Typed Wire Profile

The recommended v0 wire profile is a fenced block inside `REVIEW.md`:

```text
ReviewJudgment:
  candidate_id: cand-NNNN-name
  reviewed_at: <UTC timestamp>
  subject:
    brief_sha256: <sha256>
    landing_tier: normal | verifier-set | law-spine | mixed
    review_prompt_sha256: <sha256 or unavailable(reason)>
  reviewer:
    independence_claim: fresh-session | unknown(reason)
    write_scope_claim: REVIEW.md-only | unknown(reason)
  evidence_audit:
    eval_check: reproduced | failed | not-run-with-reason | not-applicable
    witness_ref: <path or reason>
  findings:
    - id: R1-F1
      class: evidence | correctness | tier-guard | structural-quality | boundary | test-gap | operator-held | security | docs | maintainability
      severity: blocker | transform | queue | note
      status: open | resolved | superseded | queued
      subject_ref: <path, law ref, trace ref, or none-with-reason>
      problem: <prose>
      required_change: <prose or none>
  recommendation: admit | transform | deny | needs-more-evidence
```

The exact serialization is model-layer work. This profile is included so
future tooling has a stable target, not because this statement admits a
parser.

## Meta-Harness Reading

Review judgments are a metaharness surface for Boat. Each review is a raw
trace plus a small typed index. The raw trace gives future proposers the
full diagnostic experience; the typed fields make that experience navigable
with ordinary filesystem tools and later query commands.

This preserves the Meta-Harness lesson: do not compress away the prior
review history. Store full code, scores, traces, review prose, and typed
review obligations; let later proposers inspect the filesystem selectively.

## Boundary

This statement does not admit: a checker for `REVIEW.md`; a change to
`tools/loop review`; a change to `loop land`; a new failure-class registry
entry; a proof of reviewer independence; a session receipt format; a
migration of historical reviews; a JSON-only review artifact; a semantic
claim that an admitted review is correct; any replacement for the operator
or agent decision surface; or any authority for query results. The
maintainability lens is only a finding class in v0, not a new gate by itself.
