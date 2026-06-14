# Threshold Brief: cand-0031-sparse-profile

Generated: 2026-06-14T00:14:11Z
Status: validated
Intent: Define a sparse finite-basis amount/profile representation: fixed slots of per-basis T-account cells with active flags, basis-id bounds, canonical ordering/uniqueness, zero inactive slots, and target-version consequences; no circuit rewrite yet.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/README.md` replaces `sites/ledger/specs/README.md`: +5/-0 lines vs live
- `cargo/sites/ledger/specs/1/README.md` replaces `sites/ledger/specs/1/README.md`: +5/-0 lines vs live
- `cargo/sites/ledger/specs/3/README.md` replaces `sites/ledger/specs/3/README.md`: +7/-0 lines vs live
- `cargo/sites/ledger/specs/profiles/README.md` is NEW at `sites/ledger/specs/profiles/README.md`:       11 lines
- `cargo/sites/ledger/specs/profiles/SPARSE-CELLS-1.md` is NEW at `sites/ledger/specs/profiles/SPARSE-CELLS-1.md`:      132 lines

## Witnessed behavioral delta (task: define SPARSE-CELLS/1, a sparse finite-basis amount profile: fixed per-basis T-account cells with active flags, basis-id bounds, active-prefix canonicalization, strict basis-id ordering, zero inactive slots, active zero-cell rejection, absent-as-zero interpretation, sparse state uniqueness, commitment preimage rules, and target-identity consequences. No circuit rewrite, no domain tags, no R1 allocation.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
