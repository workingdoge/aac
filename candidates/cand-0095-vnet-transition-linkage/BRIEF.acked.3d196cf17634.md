# Threshold Brief: cand-0095-vnet-transition-linkage

Generated: 2026-07-03T15:05:00Z
Status: validated
Intent: VNET/1 section 4.1 TRANSITION/1 journal linkage (closes the deferred half of cand-0094)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/world-app/provekit-vnet/src/main.nr` replaces `world-app/provekit-vnet/src/main.nr`: +220/-31 lines vs live
- `seeds/world-app/provekit-vnet/README.md` replaces `world-app/provekit-vnet/README.md`: +34/-9 lines vs live
- `seeds/world-app/provekit-vnet/Prover.toml.example` replaces `world-app/provekit-vnet/Prover.toml.example`: +15/-6 lines vs live
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +3/-3 lines vs live

## Witnessed behavioral delta (task: cand-0095 VNET/1 section 4.1 TRANSITION/1 journal linkage)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
