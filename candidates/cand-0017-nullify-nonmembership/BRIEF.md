# Threshold Brief: cand-0017-nullify-nonmembership

Generated: 2026-06-13T17:43:13Z
Status: validated
Intent: NULLIFY/1 (3/PROOF S4.2) at circuits/nullify: prove non-membership + insertion into the consumed-nullifier set via the indexed low-leaf range bracket over a strictly-sorted invariant (Field ordering by bn254::lt) — the historical-set anti-replay guard. ABI [first_root,last_root,sequence_commitment,count]. Composition: consumes a fresh EVENT-COMPLETE/1 event_nullifier and REJECTS replaying a spent one. Proven end-to-end on macOS (bb verify ok). Bound: one insertion, sorted-array fold root; production = binary indexed Merkle with succinct path proofs.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/nullify/Nargo.toml` is NEW at `circuits/nullify/Nargo.toml`: 8 lines
- `cargo/circuits/nullify/Prover.toml` is NEW at `circuits/nullify/Prover.toml`: 7 lines
- `cargo/circuits/nullify/src/main.nr` is NEW at `circuits/nullify/src/main.nr`: 190 lines

## Witnessed behavioral delta (task: NULLIFY/1 non-membership via the low-leaf range bracket over a strictly-sorted set — accept a non-member; reject an already-spent value / wrong low-leaf / tampered root; consume a fresh EVENT-COMPLETE/1 event_nullifier and reject replaying a spent one; sample witness solves)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
