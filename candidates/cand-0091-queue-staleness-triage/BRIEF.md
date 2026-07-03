# Threshold Brief: cand-0091-queue-staleness-triage

Generated: 2026-07-03T13:42:44Z
Status: validated
Intent: Resolve the three re-appended pre-fork queue entries against remote landings (cand-0090 follow-up)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +8/-8 lines vs live

## Witnessed behavioral delta (task: cand-0091 queue staleness triage: resolve/rewrite stale queue entries)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
