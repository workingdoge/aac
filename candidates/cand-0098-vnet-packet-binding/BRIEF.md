# Threshold Brief: cand-0098-vnet-packet-binding

Generated: 2026-07-03T23:23:20Z
Status: validated
Intent: P1 soundness: fundraise VNET proof must bind the packet (derive Prover.toml from vnet_link; kill the static-witness bypass)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/fundraise-demo-runner/src/index.mjs` replaces `fundraise-demo-runner/src/index.mjs`: +94/-5 lines vs live
- `seeds/fundraise-demo-runner/src/index.d.ts` replaces `fundraise-demo-runner/src/index.d.ts`: +52/-0 lines vs live
- `seeds/fundraise-demo-runner/src/vnet-provekit-binding.mjs` is NEW at `fundraise-demo-runner/src/vnet-provekit-binding.mjs`:      530 lines
- `seeds/fundraise-demo-runner/test/run-tests.mjs` replaces `fundraise-demo-runner/test/run-tests.mjs`: +107/-3 lines vs live
- `seeds/fundraise-demo-runner/README.md` replaces `fundraise-demo-runner/README.md`: +23/-5 lines vs live
- `seeds/QUEUE.md` queue-merges `candidates/QUEUE.md`: +3/-1 lines vs QUEUE.base

## Witnessed behavioral delta (task: cand-0098 fundraise VNET packet binding)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
