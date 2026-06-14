# Threshold Brief: cand-0040-fundraise-runtime-functions

Generated: 2026-06-14T04:37:50Z
Status: validated
Intent: Add a function-first JavaScript/TypeScript-facing fundraising runtime that builds and verifies FUNDRAISE-CLEARING/1 packets from typed functions, using the JSON transcript only as a fixture/audit receipt and keeping Python as a reference oracle.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/fundraise-runtime/package.json` is NEW at `fundraise-runtime/package.json`:       21 lines
- `cargo/fundraise-runtime/README.md` is NEW at `fundraise-runtime/README.md`:       26 lines
- `cargo/fundraise-runtime/src/index.mjs` is NEW at `fundraise-runtime/src/index.mjs`:      319 lines
- `cargo/fundraise-runtime/src/index.d.ts` is NEW at `fundraise-runtime/src/index.d.ts`:      122 lines
- `cargo/fundraise-runtime/test/run-tests.mjs` is NEW at `fundraise-runtime/test/run-tests.mjs`:       85 lines

## Witnessed behavioral delta (task: Add a function-first JavaScript/TypeScript-facing fundraising runtime; JSON transcript is fixture/audit receipt; Python is reference oracle only.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
