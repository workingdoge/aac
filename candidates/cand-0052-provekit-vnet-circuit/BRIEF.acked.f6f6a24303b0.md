# Threshold Brief: cand-0052-provekit-vnet-circuit

Generated: 2026-06-14T09:09:03Z
Status: validated
Intent: standalone ProveKit VNET/1 reference circuit using Noir MSM commitments
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/world-app/.gitignore` replaces `world-app/.gitignore`: +6/-0 lines vs live
- `cargo/world-app/provekit-vnet/Nargo.toml` is NEW at `world-app/provekit-vnet/Nargo.toml`:       16 lines
- `cargo/world-app/provekit-vnet/Prover.toml.example` is NEW at `world-app/provekit-vnet/Prover.toml.example`:       21 lines
- `cargo/world-app/provekit-vnet/README.md` is NEW at `world-app/provekit-vnet/README.md`:       65 lines
- `cargo/world-app/provekit-vnet/src/hash.nr` is NEW at `world-app/provekit-vnet/src/hash.nr`:       27 lines
- `cargo/world-app/provekit-vnet/src/main.nr` is NEW at `world-app/provekit-vnet/src/main.nr`:      276 lines

## Witnessed behavioral delta (task: Land a standalone ProveKit beta.19 VNET/1 reference circuit using derived Grumpkin Pedersen-vector MSM commitments, checked transition linkage, and WHIR proof verification.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
