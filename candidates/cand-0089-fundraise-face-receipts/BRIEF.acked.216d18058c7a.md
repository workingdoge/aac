# Threshold Brief: cand-0089-fundraise-face-receipts

Generated: 2026-06-14T23:46:23Z
Status: validated
Intent: Generate FUNDRAISE-CLEARING/1 simplicial face receipts from the runtime packet and expose them through the demo summary.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-runtime/src/index.mjs` replaces `fundraise-runtime/src/index.mjs`: +276/-0 lines vs live
- `cargo/fundraise-runtime/src/index.d.ts` replaces `fundraise-runtime/src/index.d.ts`: +40/-0 lines vs live
- `cargo/fundraise-runtime/test/run-tests.mjs` replaces `fundraise-runtime/test/run-tests.mjs`: +46/-0 lines vs live
- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +54/-21 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +31/-9 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +109/-1 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` replaces `web/src/data/fundraise-demo-summary.ts`: +76/-0 lines vs live

## Witnessed behavioral delta (task: Generate FUNDRAISE-CLEARING/1 simplicial face receipts from the runtime packet and expose them through the demo summary.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
