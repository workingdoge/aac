# Threshold Brief: cand-0015-event-complete-roles-nullifier

Generated: 2026-06-13T17:10:50Z
Status: validated
Intent: Grow the EVENT-COMPLETE/1 circuit toward a complete BVR: add role coverage (obligation 2 — Buyer and Supplier present + distinct, participant_set commitment) and the event_nullifier (obligation 9 — one-shot identity H(rulebook, event, parties) derived in-circuit so a replay cannot use a fresh nullifier). Negative tests reject self-dealing, a missing role, and a foreign nullifier; the nullifier is shown event/party/rulebook-distinguishing. Proven end-to-end on macOS (bb verify ok).
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/event-complete/src/main.nr` replaces `circuits/event-complete/src/main.nr`: +103/-42 lines vs live
- `cargo/circuits/event-complete/Prover.toml` replaces `circuits/event-complete/Prover.toml`: +5/-0 lines vs live

## Witnessed behavioral delta (task: EVENT-COMPLETE/1 + role coverage (obligation 2) + the in-circuit event nullifier (obligation 9, anti-replay): accept a complete receipt; reject self-dealing / missing role / foreign nullifier; nullifier event/party/rulebook-distinguishing; sample witness solves)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
