# Threshold Brief: cand-0101-dependency-mode-migration

Generated: 2026-07-04T14:28:57Z
Status: validated
Intent: migrate this instance from kernel-by-copy to dependency-mode using the kcir pilot shape
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/flake.nix` replaces `flake.nix`: +3/-0 lines vs live
- `seeds/flake.lock` replaces `flake.lock`: +19/-0 lines vs live
- `seeds/migrate-to-dependency.sh` is NEW at `migrate-to-dependency.sh`:      388 lines

## Witnessed behavioral delta (task: cand-0101 AAC dependency-mode migration machinery)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
