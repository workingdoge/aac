# Threshold Brief: cand-0065-fundraise-slotted-controls

Generated: 2026-06-14T11:43:59Z
Status: validated
Intent: Keep fundraise controls owned by aac-fundraise-demo while rendering the clickable buttons as component-owned light-DOM slotted controls.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +69/-37 lines vs live

## Witnessed behavioral delta (task: Keep fundraise controls owned by the component while rendering clickable controls as slotted light-DOM buttons.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
