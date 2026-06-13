# Threshold Brief: cand-0014-event-complete-circuit

Generated: 2026-06-13T17:01:03Z
Status: validated
Intent: The EVENT-COMPLETE/1 circuit at circuits/event-complete: takes the typed event as private witness, runs Phi_R in-circuit (rulebook crate), and binds journal_commitment to the COMPILED journal — so the proof attests journal_commitment commits to Phi_R(event), a P^n zero-account, not an arbitrary balanced journal. Realizes obligations 4+5+10. Includes making rulebook's struct fields pub for cross-crate use. Proven end-to-end on arm64 macOS (bb verify ok, 14,348 gates); negative tests reject a journal commitment from a different event and a tampered event commitment.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/rulebook/src/lib.nr` replaces `circuits/rulebook/src/lib.nr`: +4/-4 lines vs live
- `cargo/circuits/event-complete/Nargo.toml` is NEW at `circuits/event-complete/Nargo.toml`: 7 lines
- `cargo/circuits/event-complete/Prover.toml` is NEW at `circuits/event-complete/Prover.toml`: 4 lines
- `cargo/circuits/event-complete/src/main.nr` is NEW at `circuits/event-complete/src/main.nr`: 110 lines

## Witnessed behavioral delta (task: EVENT-COMPLETE/1 circuit — Phi_R in-circuit binds journal_commitment to the compiled journal (accept the schema image; reject a journal commitment from a different event; reject a tampered event commitment); sample witness solves)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
