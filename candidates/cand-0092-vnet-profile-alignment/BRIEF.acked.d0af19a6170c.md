# Threshold Brief: cand-0092-vnet-profile-alignment

Generated: 2026-07-03T13:57:04Z
Status: validated
Intent: Align world-app/provekit-vnet to the full PEDERSEN-VECTOR/1 profile and VNET/1 public surface
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +2/-0 lines vs live

## Witnessed behavioral delta (task: Record the cand-0092 PEDERSEN-VECTOR/1 ProveKit generator-pinning blocker instead of silently choosing soundness-critical generators.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
