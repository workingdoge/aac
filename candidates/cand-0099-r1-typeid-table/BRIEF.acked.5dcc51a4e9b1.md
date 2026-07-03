# Threshold Brief: cand-0099-r1-typeid-table

Generated: 2026-07-03T23:00:32Z
Status: validated
Intent: Compute R1's typeId table + 2/FACT canonical-encoding vectors (every cross-thread TypedFact depends on this)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/candidates/QUEUE.md` queue-merges `candidates/QUEUE.md`: +2/-0 lines vs QUEUE.base

## Witnessed behavioral delta (task: Record the cand-0099 cjson/1 and TypeDecl byte-determination blockers instead of computing arbitrary R1 typeIds.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
