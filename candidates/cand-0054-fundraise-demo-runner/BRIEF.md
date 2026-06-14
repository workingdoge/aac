# Threshold Brief: cand-0054-fundraise-demo-runner

Generated: 2026-06-14T09:29:08Z
Status: validated
Intent: add a one-command ProveKit fundraise demo runner
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-demo-runner/package.json` is NEW at `fundraise-demo-runner/package.json`:       24 lines
- `cargo/fundraise-demo-runner/README.md` is NEW at `fundraise-demo-runner/README.md`:       21 lines
- `cargo/fundraise-demo-runner/src/index.mjs` is NEW at `fundraise-demo-runner/src/index.mjs`:      172 lines
- `cargo/fundraise-demo-runner/src/index.d.ts` is NEW at `fundraise-demo-runner/src/index.d.ts`:       79 lines
- `cargo/fundraise-demo-runner/bin/fundraise-demo.mjs` is NEW at `fundraise-demo-runner/bin/fundraise-demo.mjs`:       42 lines
- `cargo/fundraise-demo-runner/test/run-tests.mjs` is NEW at `fundraise-demo-runner/test/run-tests.mjs`:       74 lines

## Witnessed behavioral delta (task: Add a one-command fundraise demo runner that emits a ProveKit live-proof workflow receipt and settlement action.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
