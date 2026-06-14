# Threshold Brief: cand-0032-ledger-receipt-split

Generated: 2026-06-14T01:28:37Z
Status: validated
Intent: Slim circuits/ledger to the KERNEL commitment seam (journal_commitment + TAG_JOURNAL=3) and move the app-side receipt identities (participant_set, event_nullifier) into a new circuits/receipt lib. Reassign their colliding tags TAG_PARTY 122->124 and TAG_NULL 123->125 off R1's receipt-reference block (3/PROOF Annex A app range 120-255); append R1 rows 124/125; reconcile TAG_EVENT=120 in R1 (the receipt-reference leaf, realized by rulebook event_commitment -- no code change). event-complete imports journal_commitment from ledger and participant_set/event_nullifier from receipt; its witness/Prover.toml regenerated (participant_set/event_nullifier values change). transition/nullify untouched -- the kernel consumes nullifiers OPAQUELY, so no on-chain registry change (recompute-vs-consume seam rule). nargo test green workspace-wide; resolves the 122/123 tag-collision soundness concern (3/PROOF Annex A: tag reuse across structures is a soundness failure). Web aac-receipt value cascade queued as a follow-up.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/receipt/Nargo.toml` is NEW at `circuits/receipt/Nargo.toml`:        7 lines
- `cargo/circuits/receipt/src/lib.nr` is NEW at `circuits/receipt/src/lib.nr`:       32 lines
- `cargo/circuits/ledger/src/lib.nr` replaces `circuits/ledger/src/lib.nr`: +9/-26 lines vs live
- `cargo/circuits/event-complete/Nargo.toml` replaces `circuits/event-complete/Nargo.toml`: +1/-0 lines vs live
- `cargo/circuits/event-complete/src/main.nr` replaces `circuits/event-complete/src/main.nr`: +2/-1 lines vs live
- `cargo/circuits/event-complete/Prover.toml` replaces `circuits/event-complete/Prover.toml`: +2/-2 lines vs live
- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/sites/ledger/specs/registers/R1.md` replaces `sites/ledger/specs/registers/R1.md`: +9/-0 lines vs live

## Witnessed behavioral delta (task: slim circuits/ledger to the kernel commitment seam (journal_commitment + TAG_JOURNAL=3); move the app-side receipt identities (participant_set, event_nullifier) into a new circuits/receipt lib with tags reassigned off the 122/123 collision with R1 receipt-reference block to 124/125 (3/PROOF Annex A); append R1 rows 124/125 + reconcile 120; rewire event-complete (journal_commitment from ledger, identities from receipt) and regenerate its witness; transition/nullify untouched. nargo test --workspace green (8 crates), all witnesses solve, the cascade is scoped to the app identities (kernel commitment byte-identical), and a mutant proves the slim-probe non-vacuous.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
