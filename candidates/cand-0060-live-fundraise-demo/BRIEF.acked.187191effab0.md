# Threshold Brief: cand-0060-live-fundraise-demo

Generated: 2026-06-14T11:00:33Z
Status: validated
Intent: Add a live localhost fundraise demo API and frontend control that runs the ProveKit fundraise proof on demand while keeping the captured receipt as fallback.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/package.json` replaces `fundraise-demo-runner/package.json`: +1/-1 lines vs live
- `cargo/fundraise-demo-runner/bin/fundraise-demo.mjs` replaces `fundraise-demo-runner/bin/fundraise-demo.mjs`: +24/-2 lines vs live
- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +176/-0 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +30/-0 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +32/-0 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +148/-21 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +9/-3 lines vs live

## Witnessed behavioral delta (task: Add a live localhost fundraise demo API and frontend control while preserving the captured receipt fallback.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
