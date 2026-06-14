# Threshold Brief: cand-0053-provekit-cli-adapter

Generated: 2026-06-14T09:22:18Z
Status: validated
Intent: wire native ProveKit CLI verification into the fundraise adapter
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/fundraise-provekit-adapter/package.json` replaces `fundraise-provekit-adapter/package.json`: +1/-1 lines vs live
- `cargo/fundraise-provekit-adapter/README.md` replaces `fundraise-provekit-adapter/README.md`: +28/-7 lines vs live
- `cargo/fundraise-provekit-adapter/src/index.mjs` replaces `fundraise-provekit-adapter/src/index.mjs`: +207/-0 lines vs live
- `cargo/fundraise-provekit-adapter/src/index.d.ts` replaces `fundraise-provekit-adapter/src/index.d.ts`: +56/-0 lines vs live
- `cargo/fundraise-provekit-adapter/test/run-tests.mjs` replaces `fundraise-provekit-adapter/test/run-tests.mjs`: +87/-1 lines vs live

## Witnessed behavioral delta (task: Wire the Nix-packaged native ProveKit CLI path into the fundraise verifier receipt adapter.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
