# Threshold Brief: cand-0006-noir-transition

Generated: 2026-06-13T07:05:13Z
Status: validated
Intent: The TRANSITION/1 Noir circuit (3/PROOF §4.1) for the default journal-balance profile: bounded amounts (Field→u64→Field, the journal_sum_field_sound discipline), per-basis journal balance, begin+posted=end state arithmetic, recomputed account/nullifier roots, nullifier distinctness with root-unchanged-absent-consumption, fact_fold per Annex B with domain tags, recomputed journal_commitment, unconstrained context_commitment — with a pacioli library crate mirroring Core.lean and a nargo test suite (accept valid, reject unbalanced/tampered/double-spend) as the eval gate.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=e656d083e825bd60e35c27316fa623f45d838fedecc699a1725b2e9089cb075a

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` is NEW at `circuits/Nargo.toml`: 3 lines
- `cargo/circuits/README.md` is NEW at `circuits/README.md`: 102 lines
- `cargo/circuits/pacioli/Nargo.toml` is NEW at `circuits/pacioli/Nargo.toml`: 6 lines
- `cargo/circuits/pacioli/src/lib.nr` is NEW at `circuits/pacioli/src/lib.nr`: 124 lines
- `cargo/circuits/transition/Nargo.toml` is NEW at `circuits/transition/Nargo.toml`: 7 lines
- `cargo/circuits/transition/Prover.toml` is NEW at `circuits/transition/Prover.toml`: 47 lines
- `cargo/circuits/transition/src/main.nr` is NEW at `circuits/transition/src/main.nr`: 327 lines

## Witnessed behavioral delta (task: TRANSITION/1 Noir circuit (3/PROOF S4.1) — compiles, conformance suite passes (accept valid; reject unbalanced/tampered/double-spend/zero-multiplicity), sample witness solves, wired to journal_sum_field_sound)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
