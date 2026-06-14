# Threshold Brief: cand-0074-fundraise-order-fill-ui

Generated: 2026-06-14T13:03:02Z
Status: validated
Intent: Reframe the fundraise page as a private order-fill demo with coherent controls and visible fill economics.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +169/-25 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +16/-15 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` replaces `web/src/data/fundraise-demo-summary.ts`: +2/-2 lines vs live

## Witnessed behavioral delta (task: Reframe the fundraise page as a private order-fill demo with coherent controls and visible fill economics.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
