# Threshold Brief: cand-0084-fundraise-htmx-verify-form

Generated: 2026-06-14T16:09:06Z
Status: validated
Intent: Make fundraise verification a submitted htmx verifier form instead of a reveal.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +374/-4 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +49/-0 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +59/-0 lines vs live
- `cargo/web/src/components/aac-htmx.ts` is NEW at `web/src/components/aac-htmx.ts`:       78 lines
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +259/-19 lines vs live
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +1/-0 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +14/-12 lines vs live

## Witnessed behavioral delta (task: Make fundraise verification a submitted htmx verifier form instead of a reveal.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
