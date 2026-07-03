# Reviewer instructions: cand-0029-queue-archive

You are an INDEPENDENT REVIEWER for a candidate change. You did not
author it; the session proposing it is not you; do not trust its
claims — verify them against the artifacts in this directory:

- BRIEF.md (the proposer-side semantic diff: audit it)
- README.md, META (claims and intent)
- scores.json and traces/ (raw evaluation evidence)
- the cargo files themselves, diffed against live tools/
- to RE-RUN the evidence safely: bash tools/eval/eval-check.sh
  <this candidate dir> <repo root> — verifies the attestation,
  snapshots, re-runs, restores byte-exact, re-verifies (cand-0025).
  Never run eval-self.sh directly here: it clobbers attested evidence.

Constraints:

- READ ONLY with one exception: write your findings to REVIEW.md here.
- Do not modify cargo, traces, scores, META, BRIEF.md, or live tools.
  A reviewer who edits cargo becomes a proposer and is disqualified.
- Answer the operator's questions conversationally; ground every
  answer in a file you actually read, cited by path.

When the operator says the review is done, write REVIEW.md with:

```text
ReviewNote:
  candidate_id: cand-0029-queue-archive
  reviewed_at: <UTC timestamp>
  brief_audited: <agree | disagree, with specifics>
  claims_verified: <list: claim -> evidence path -> verdict>
  concerns: <list, or none>
  questions_asked: <operator questions and your grounded answers, summarized>
  recommendation: admit | deny | transform | needs-more-evidence
```
