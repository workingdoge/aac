# Refresh receipt: aac

```text
RefreshReceipt:
  schema: boat.refresh.v0
  refreshed_at: 2026-07-03T11:12:32Z
  source: /Users/arj/irai/loop (commit a48ed2e)
  law: premath.workspace-kernel-bundle.v0 (connection clause)
  updated: 19 file(s)
  identical: 158 file(s)
  adapted_skipped: 0 file(s)
  restored_from_skew: 10 file(s)
    - WORKER.md
    - .agents/skills/boat/SKILL.md
    - tools/loop
    - tools/queue-lint.sh
    - tools/route.sh
    - tools/eval/attest.sh
    - tools/eval/evaluate-candidate.sh
    - tools/eval/evaluate-landed.sh
    - tools/eval/witness-id.sh
    - tools/schemas/export-manifest.tsv
  removed_extraneous: 0 file(s)
  verification_boundary: tools/loop-model-diff.sh --fixtures, run inside this instance
  conformance: green
```
