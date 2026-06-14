# Threshold Brief: cand-0029-queue-archive

Generated: 2026-06-13T21:26:27Z
Status: validated
Intent: ship tools/queue-archive.sh so aac can bound its queue as working memory (resolved entries archive out, check warns over a soft open bound) — boat cand-0053/0054 kernel hygiene; aac already carries the queue-lib.sh dependency
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `queue-archive.sh` is NEW at `tools/queue-archive.sh`: 173 lines
- `export-manifest.tsv` replaces `tools/schemas/export-manifest.tsv`: +1/-0 lines vs live

## Witnessed behavioral delta (task: ship tools/queue-archive.sh (manifest -0/+1) so aac can bound its queue as working memory: the manifest still parses with the new entry provided by the LANDING map and the queue-lib dep present, check runs read-only on aac's live queue (exit 0), archive on a synthetic queue is content-preserving (resolved moves, opens + preamble byte-untouched, no line lost, both lint-clean, idempotent rerun), and the delta is additive with tools/loop untouched)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
