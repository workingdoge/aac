# Threshold Brief: cand-0078-fundraise-summary-driven-ui

Generated: 2026-06-14T13:53:38Z
Status: validated
Intent: Make the fundraise presentation render order, fill, balance, and reconciliation data from the runner summary instead of component constants.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +168/-3 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +55/-0 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +51/-0 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +27/-61 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` replaces `web/src/data/fundraise-demo-summary.ts`: +49/-1 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +6/-7 lines vs live

## Witnessed behavioral delta (task: Render the fundraise demo from runner summary order, fill, opening-balance, and reconciliation fields instead of component constants.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
