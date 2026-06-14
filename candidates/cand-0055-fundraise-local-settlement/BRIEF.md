# Threshold Brief: cand-0055-fundraise-local-settlement

Generated: 2026-06-14T09:46:12Z
Status: validated
Intent: add local Foundry settlement submission to the fundraise demo runner
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/README.md` replaces `fundraise-demo-runner/README.md`: +22/-0 lines vs live
- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +392/-38 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +78/-0 lines vs live
- `cargo/fundraise-demo-runner/bin/fundraise-demo.mjs` replaces `fundraise-demo-runner/bin/fundraise-demo.mjs`: +23/-4 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +71/-0 lines vs live

## Witnessed behavioral delta (task: Add local Foundry deploy/sign/settle submission to the ProveKit fundraise demo runner.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
