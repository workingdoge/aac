# Loop-model differential fixture corpus

Statement: `premath.loop-model.v0` (LM-1.2 agreement projection, LM-1.4
coherence evidence). Consumer: `tools/loop-model-diff.sh` (the
`evaluate-landed` suite member runs `--fixtures` over this directory).

Each `fix-*/` is a FROZEN candidate-shaped record — data, never a real
candidate. The `fix-` prefix is deliberate: nothing here matches the
`cand-*` globs the store tools sweep. Attestations are real (written by
`tools/eval/attest.sh` at build time; the chain is path-relative, so it
verifies wherever the record is copied). `fix-attest-tampered`'s trace
was edited AFTER attestation, deliberately.

Coverage by construction (witnessed by the cand-0046 evaluation):

- validate failure classes: record-formation-incomplete,
  vocabulary-atom-failure, sigma-missing-witness,
  verifier_contract_violation — plus admitted docs and multi-failure
  ordering.
- auto refusal points: all eleven LM-1.2 tokens, including the
  `.//`-normalization asymmetry (`fix-landing-dotslash` passes validate
  and dies at land) and the landed terminal.
- reflect: all ten decision-table rows.
- scores_verdict: all five tokens (pass, "", MALFORMED-JSON,
  json-quoted, no-scores).

Honest asymmetries this corpus pins (loop behavior, captured not fixed):

- `fix-scores-dup-attested`: a duplicate-key verdict file attests and
  VALIDATES fine (attest.sh is line-based) — only the verdict readers
  refuse it.
- `fix-validate-refused`: reflect witnesses evidence for a candidate
  validate rejects (reflect never runs validate).
- `fix-rolled-back`: `loop auto` RE-LANDS a rolled-back candidate (no
  status gate in the auto chain; the prior REVIEW.md still satisfies
  the tier guard). Queued as a finding by cand-0046.

Regenerable via `candidates/cand-0046-loop-model/fixtures-build.py`
(build provenance; regeneration re-stamps identical content except
fresh attestation hashes over identical bytes — the corpus is frozen
data, edits go through new candidates).
