```
ReviewJudgment:
  candidate_id: cand-0100-cjson-canonicalization
  reviewed_at: 2026-07-04T00:55:00Z
  subject:
    brief_sha256: f676867e0b793850a63be69498823d3568b212bc705561cfa1b8379968eaa361
    landing_tier: normal
    review_prompt_sha256: f950a47b9e6784cc0b8a0fdc08a14723433df53d3446631251551d4e7f67cc9c
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0100-cjson-canonicalization . -> REPRODUCED (pass attested, pass reproduced, evidence intact)"
  findings: none
  recommendation: admit
```

ReviewNote:
  candidate_id: cand-0100-cjson-canonicalization
  reviewed_at: 2026-07-04T00:55:00Z
  brief_audited: agree — the BRIEF's cargo list matches the seeds/ tree byte-for-byte and verdict pass is reproducible.
  claims_verified:
    - claim: All six R1 typeIds are sha256:<hex> of enc(TypeDecl) under cjson/1
      evidence:
        - python3 seeds/sites/ledger/specs/2/reference/cjson1_encode.py --sha256 <each TypeDecl>
        - candidates/cand-0100-cjson-canonicalization/seeds/sites/ledger/specs/registers/R1.md:11-17
        - candidates/cand-0100-cjson-canonicalization/seeds/sites/ledger/specs/2/vectors/typedecl-typeids.json
      verdict: PASS — independently recomputed all six digests (cjson/1=2e9b28f0..., sha256/1=9b72b1e8..., d2f-31be/1=97b77205..., uh-bn254/1=f7e97f55..., name-ens/1=b570938c..., data-walrus/1=88c4839f...); every digest matches R1.md and the typedecl-typeids vector byte-for-byte.
    - claim: Additive-only vs live specs (prior 2/FACT pins byte-preserved)
      evidence:
        - diff -u sites/ledger/specs/2/README.md .../seeds/.../2/README.md (+14/-0)
        - diff -u sites/ledger/specs/registers/R1.md .../seeds/.../R1.md (+14/-7 - the 7 removed lines are all _tbd_ placeholders getting filled)
      verdict: PASS — integer/key-sort/duplicate-key/no-whitespace/no-surrogate rules in section 2 are byte-identical to live; tag 120-129 assignments in R1.md are byte-identical to live; only _tbd_ handle rows are replaced with computed identities.
    - claim: JCS-key-order mutant and uppercase-hex mutant both FAIL
      evidence:
        - Ran an insertion-order (non-sorted) mutant encoder against seeds/.../cjson-1.json -> digest 69e8531d13e945f7...; canonical is 2e9b28f08ecc1509...
        - Encoded U+001A with uppercase hex -> "" vs canonical ""
      verdict: PASS — both mutations produce distinct canonical bytes/digests, so the pinned key-order and lowercase-hex rules are load-bearing.
    - claim: cjson/1 is not RFC 8785/JCS (accurate)
      evidence:
        - candidates/.../seeds/sites/ledger/specs/2/README.md:52-54
        - candidates/.../seeds/sites/ledger/specs/2/vectors/cjson1-key-order.json:5-15
      verdict: PASS — cjson/1 sorts object keys by UTF-8 bytes (JCS uses UTF-16 code units) and uses arbitrary-precision minimal decimal integers with no exponent forms (JCS uses ES6 Number). The key-order vector concretely exhibits U+E000 vs U+1F600 as a UTF-8 / JCS-UTF-16 disagreement.
    - claim: Escape rule is total on the string grammar
      evidence:
        - candidates/.../seeds/sites/ledger/specs/2/vectors/cjson1-escape.json (34 cases)
        - candidates/.../seeds/sites/ledger/specs/2/reference/cjson1_encode.py:95-111
      verdict: PASS — the vector enumerates all 32 control characters U+0000..U+001F plus U+0022 (\") and U+005C (\\); every JSON short escape is pinned, every other control character maps to lowercase \u00xx, no other character is escaped. The encoder matches this partition exactly.
    - claim: TypeDecl grammar has no conflict with existing docs
      evidence:
        - candidates/.../seeds/sites/ledger/specs/2/README.md:65-73
        - each seeds/.../type-declarations/*.json - kind=string, version=integer, schema=Value, name=string
      verdict: PASS — the grammar { kind:string, version:integer, schema:Value, name?:string } is a strict refinement of the existing sketch; every one of the six TypeDecl documents satisfies it. The additional-member-changes-identity clause is consistent with 2/FACT section 2's byte-equality doctrine.
    - claim: uh-wrap-groth16/1 reserved honestly (no deployed identity)
      evidence:
        - candidates/.../seeds/sites/ledger/specs/registers/R1.md:15
        - candidates/.../seeds/sites/ledger/specs/registers/R1.md:19-24 (provenance note)
      verdict: PASS — R1.md row reads "reserved; not assigned in this register"; no uh-wrap-groth16-1.json TypeDecl exists in type-declarations/. Provenance note explicitly records the reservation.
    - claim: Queue merge resolves cand-0099 cleanly
      evidence:
        - diff -u candidates/QUEUE.md .../seeds/candidates/QUEUE.md (+2/-3 vs QUEUE.base)
      verdict: PASS — the cand-0099 obstruction row is removed from Open; a corresponding [resolved cand-0100..., 2026-07-03] row is inserted at the top of Resolved. All other open items, resolved items, and tail entries are byte-preserved.
    - claim: Attested evidence reproduces
      evidence:
        - bash tools/eval/eval-check.sh candidates/cand-0100-cjson-canonicalization . -> REPRODUCED
      verdict: PASS — attestation verified (703ac3ab5bf2), snapshot taken, evaluator re-ran, evidence restored byte-exact, re-verified. Fresh-run harness rc=0, verdict pass.
  concerns: none
  questions_asked: none (non-interactive convening; no operator questions to answer).
  recommendation: admit
