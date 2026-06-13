# Threshold Brief: cand-0016-ledger-composition

Generated: 2026-06-13T17:24:37Z
Status: validated
Intent: Lift a shared circuits/ledger lib (canonical journal_commitment + participant_set + event_nullifier) so EVENT-COMPLETE/1 and TRANSITION/1 COMPOSE on one commitment: TRANSITION/1's journal_commitment is unchanged (byte-identical, lifted verbatim), EVENT-COMPLETE/1 adopts the canonical form, and a composition test shows TRANSITION/1 posts exactly the journal_commitment the BVR certifies (0x014292…) and consumes the BVR's event_nullifier. rulebook gains account indices + the schema event_commitment. Proven end-to-end on macOS.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/ledger/Nargo.toml` is NEW at `circuits/ledger/Nargo.toml`: 5 lines
- `cargo/circuits/ledger/src/lib.nr` is NEW at `circuits/ledger/src/lib.nr`: 62 lines
- `cargo/circuits/rulebook/src/lib.nr` replaces `circuits/rulebook/src/lib.nr`: +40/-43 lines vs live
- `cargo/circuits/transition/Nargo.toml` replaces `circuits/transition/Nargo.toml`: +2/-0 lines vs live
- `cargo/circuits/transition/src/main.nr` replaces `circuits/transition/src/main.nr`: +44/-12 lines vs live
- `cargo/circuits/event-complete/Nargo.toml` replaces `circuits/event-complete/Nargo.toml`: +2/-1 lines vs live
- `cargo/circuits/event-complete/src/main.nr` replaces `circuits/event-complete/src/main.nr`: +33/-90 lines vs live
- `cargo/circuits/event-complete/Prover.toml` replaces `circuits/event-complete/Prover.toml`: +1/-1 lines vs live

## Witnessed behavioral delta (task: shared ledger lib unifies EVENT-COMPLETE/1 + TRANSITION/1 on journal_commitment + event_nullifier — composition test (TRANSITION posts the BVR journal/nullifier), TRANSITION byte-identical (landed Prover.toml solves), event-complete solves)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
