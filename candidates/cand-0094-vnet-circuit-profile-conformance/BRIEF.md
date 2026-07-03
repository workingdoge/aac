# Threshold Brief: cand-0094-vnet-circuit-profile-conformance

Generated: 2026-07-03T14:46:29Z
Status: validated
Intent: Align world-app/provekit-vnet to the completed PEDERSEN-VECTOR/1 profile (closes the VNET/1 queue entry's circuit half)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/world-app/provekit-vnet/src/main.nr` replaces `world-app/provekit-vnet/src/main.nr`: +415/-57 lines vs live
- `seeds/world-app/provekit-vnet/README.md` replaces `world-app/provekit-vnet/README.md`: +42/-16 lines vs live
- `seeds/world-app/provekit-vnet/Prover.toml.example` replaces `world-app/provekit-vnet/Prover.toml.example`: +15/-11 lines vs live
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +3/-1 lines vs live

## Witnessed behavioral delta (task: cand-0094 VNET circuit PEDERSEN-VECTOR/1 profile conformance)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
