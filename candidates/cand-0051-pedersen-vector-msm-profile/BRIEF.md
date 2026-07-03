# Threshold Brief: cand-0051-pedersen-vector-msm-profile

Generated: 2026-06-14T08:18:46Z
Status: validated
Intent: port the governed ProveKit MSM-only Pedersen vector profile into vnet fundraising
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` is NEW at `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md`:      190 lines
- `cargo/sites/ledger/specs/profiles/README.md` replaces `sites/ledger/specs/profiles/README.md`: +1/-0 lines vs live
- `cargo/sites/ledger/specs/applications/VNET-1.md` replaces `sites/ledger/specs/applications/VNET-1.md`: +10/-0 lines vs live

## Witnessed behavioral delta (task: Port the ProveKit MSM-only PEDERSEN-VECTOR/1 profile into vnet-fundraising while preserving the existing BN254 reference profile and leaving the prototype circuit unlanded.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
