# Threshold Brief: cand-0079-fundraise-verifier-surface

Generated: 2026-06-14T14:14:06Z
Status: validated
Intent: Expose the real ProveKit verifier receipt in the fundraise summary and render it as a visible verifier panel.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +28/-0 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +19/-0 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +13/-0 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +86/-15 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` replaces `web/src/data/fundraise-demo-summary.ts`: +25/-0 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +8/-4 lines vs live

## Witnessed behavioral delta (task: Expose the native ProveKit verifier receipt in the fundraise summary and render it visibly in the demo.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
