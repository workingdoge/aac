# Threshold Brief: cand-0097-web-receipt-value-cascade

Generated: 2026-07-03T17:29:10Z
Status: validated
Intent: Web aac-receipt value cascade: refresh stale tag-reassignment values (cand-0032 follow-up)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/web/src/components/aac-receipt.ts` replaces `web/src/components/aac-receipt.ts`: +27/-0 lines vs live
- `seeds/web/src/content/docs/components.mdx` replaces `web/src/content/docs/components.mdx`: +9/-0 lines vs live
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +2/-2 lines vs live

## Witnessed behavioral delta (task: cand-0097 web aac-receipt value cascade: update component and /components public inputs after cand-0032 receipt tag reassignment, verify beta.14 event_complete values, build or block honestly, and resolve the queue entry.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
