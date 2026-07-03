# Threshold Brief: cand-0086-ledger-statement-interface

Generated: 2026-06-14T20:20:17Z
Status: validated
Intent: Define LEDGER/1 as the committed private ledger state and statement interface, giving fundraise demo its missing 0-simplex.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/LEDGER-1.md` is NEW at `sites/ledger/specs/applications/LEDGER-1.md`:      267 lines
- `cargo/sites/ledger/specs/applications/README.md` replaces `sites/ledger/specs/applications/README.md`: +12/-8 lines vs live

## Witnessed behavioral delta (task: Add LEDGER/1 as the committed private ledger state and statement interface: ledger as vertex, statements as lawful projections, TRANSITION/1 binding, and Premath Gate failure vocabulary.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
