# Threshold Brief: cand-0057-fundraise-web-demo

Generated: 2026-06-14T10:20:25Z
Status: validated
Intent: Add a token-themed fundraise demo page rendering the ProveKit-to-local-settlement summary artifact.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-fundraise-demo.ts` is NEW at `web/src/components/aac-fundraise-demo.ts`:      489 lines
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +1/-0 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` is NEW at `web/src/data/fundraise-demo-summary.ts`:       74 lines
- `cargo/web/src/content/docs/fundraise.mdx` is NEW at `web/src/content/docs/fundraise.mdx`:       24 lines
- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +1/-1 lines vs live

## Witnessed behavioral delta (task: Add a token-themed /fundraise presentation console for the ProveKit-to-local-settlement demo summary.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
