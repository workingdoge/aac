# Review: cand-0099-r1-typeid-table

```text
ReviewJudgment:
  candidate_id: cand-0099-r1-typeid-table
  reviewed_at: 2026-07-03T18:15:00Z
  subject:
    brief_sha256: 5dcc51a4e9b14e68637bf9c1775fa3f209f8b5a96698318d0cc5a75bc548621c
    landing_tier: normal
    review_prompt_sha256: be9a023fbb6409933128304d3a60e827a0d8bc2a4c12a01f204ac80264a37dc6
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: bash tools/eval/eval-check.sh candidates/cand-0099-r1-typeid-table . (REPRODUCED, attestation 8b702a6cc5f2, fresh-run pass rc=0)
  findings: none
  recommendation: admit
```

```text
ReviewNote:
  candidate_id: cand-0099-r1-typeid-table
  reviewed_at: 2026-07-03T18:15:00Z
  brief_audited: >
    agree — BRIEF.md declares the cargo as a queue-merge only (+2 lines
    over QUEUE.base at seeds/candidates/QUEUE.md). Diff confirmed: the
    added QUEUE row is a single-line [open] obstruction entry naming the
    two byte-determination gaps and pointing to the next-candidate fix.
    No sites/ or tools/ files are edited; LANDING encodes only the
    queue-merge; META.status=validated; VALIDATE.json admitted.
  claims_verified:
    - claim: "2/FACT section 2 does not choose a JSON escape spelling
        for control characters, so cjson/1 is not byte-unique."
      evidence: sites/ledger/specs/2/README.md line 41-42
      verdict: confirmed — the clause reads "mandatory escaping of \"
        \\ and control characters, and no other escaping". Both the
        two-char shortcuts (\n, \t, \r, \b, \f) and the six-char
        \uXXXX form escape a control character with no unrelated
        escaping. The spec picks neither, so U+000A can be canonically
        encoded as either \n or 
 — distinct bytes, both
        conforming. Basis collapse risk per section 8 is real.
    - claim: "TypeDecl is only sketched; no byte-canonical documents
        exist in the repo for R1's seven handles."
      evidence: sites/ledger/specs/2/README.md line 59; repo-wide grep
      verdict: confirmed — the only appearance of TypeDecl in specs is
        the sketch TypeDecl := { kind, name?, version, schema, ... }.
        No authored declaration document exists for cjson/1, sha256/1,
        d2f-31be/1, uh-bn254/1, uh-wrap-groth16/1, name-ens/1, or
        data-walrus/1 anywhere under sites/ledger/specs.
    - claim: "R1 handle-to-typeId table still contains _tbd_ rows."
      evidence: sites/ledger/specs/registers/R1.md lines 8-15
      verdict: confirmed — all seven handle rows read _tbd_.
    - claim: "Refusing was correct: computing typeIds now would bind
        arbitrary bytes rather than digesting authored declarations."
      evidence: cross-check of 2/FACT section 2 grammar (lines 33-46)
        plus section 3 identity rule (lines 52-66); no cjson/1 reference
        encoder or TypeDecl document exists anywhere in the repo.
      verdict: confirmed — any typeId emitted today would be H(enc(D))
        for a D chosen by the worker, not by the specification; the
        control-character ambiguity would propagate into enc even for a
        pinned D. Per section 8 (basis collapse), this is precisely the
        deviation the spec warns against.
    - claim: "Evaluator verdict = pass, ATTESTED."
      evidence: tools/eval/eval-check.sh output
      verdict: reproduced — attestation 8b702a6cc5f2 verified; snapshot
        plus fresh-run pass rc=0; evidence restored byte-exact and
        re-verified. Five checks (t01..t05) all pass.
    - claim: "Obstruction queue entry is scoped precisely enough for a
        follow-up 2/FACT completion candidate."
      evidence: seeds/candidates/QUEUE.md queue-merge (diff vs QUEUE.base)
      verdict: confirmed — the row calls out (a) fixing the cjson/1
        control-character escape spelling normatively and (b) authoring
        the TypeDecl document schema/location, then computing R1 from
        those authored inputs. That is a directly actionable scope.
    - claim: "No cargo pretends to be the fix (per reviewer prompt)."
      evidence: LANDING, BRIEF.md, cargo diff
      verdict: confirmed — the only landing material is the QUEUE row;
        no spec edits, no encoder, no typeId assignments, no schema
        proposal. This candidate is an obstruction record, not a fix.
  concerns: none
  questions_asked: none — non-interactive convening; no operator present.
  recommendation: admit
```
