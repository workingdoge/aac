# Threshold Brief: cand-0070-fundraise-same-origin-demo

Generated: 2026-06-14T12:15:39Z
Status: validated
Intent: Serve the fundraise static UI and proof API from one localhost origin so the live component can complete in browser environments that block cross-port local fetches.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +86/-9 lines vs live
- `cargo/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +3/-0 lines vs live
- `cargo/fundraise-demo-runner/bin/fundraise-demo.mjs` replaces `fundraise-demo-runner/bin/fundraise-demo.mjs`: +4/-1 lines vs live
- `cargo/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +18/-0 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +9/-1 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +4/-3 lines vs live

## Witnessed behavioral delta (task: Serve the fundraise UI and live proof API from one localhost origin.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
