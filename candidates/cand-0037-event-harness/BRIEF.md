# Threshold Brief: cand-0037-event-harness

Generated: 2026-06-14T03:29:06Z
Status: validated
Intent: Factor the reusable EVENT/BVR proof harness out of event-complete (the spike came back CLEAN). New app lib circuits/event-harness owns the generic CompiledJournal<R,B> + EventPublics + discharge<R,B>, which discharges the schema-AGNOSTIC EVENT/1 obligations (party binding, P^n balance, journal_commitment binding, one-shot nullifier) over a compiled journal -- natural because pacioli/ledger primitives are already generic; no PostingProgram trait needed (a circuit can't have a generic main). rulebook repoints CompiledJournal to the harness (one generic annotation on compile's return); event-complete's main does the schema-specific half (roles, event_commitment, Phi_P=compile) then calls discharge. App-side only: cand-0033 kernel/app law holds, no kernel crate touched. VALUE-PRESERVING: public values + witness unchanged (existing Prover.toml solves); the public ABI param stays rulebook_id (spec-synced), only the INTERNAL harness API uses posting_program_id. Goods-receipt-invoice is the ONE posting program; NO second schema (follow-up). Witnessed: nargo test --workspace green (9 crates incl. event_harness with accept + reject-wrong-journal-commitment/nullifier/party tests), all witnesses solve, boundary checker still clean.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/event-harness/Nargo.toml` is NEW at `circuits/event-harness/Nargo.toml`:        9 lines
- `cargo/circuits/event-harness/src/lib.nr` is NEW at `circuits/event-harness/src/lib.nr`:      102 lines
- `cargo/circuits/rulebook/Nargo.toml` replaces `circuits/rulebook/Nargo.toml`: +1/-0 lines vs live
- `cargo/circuits/rulebook/src/lib.nr` replaces `circuits/rulebook/src/lib.nr`: +2/-7 lines vs live
- `cargo/circuits/event-complete/Nargo.toml` replaces `circuits/event-complete/Nargo.toml`: +2/-2 lines vs live
- `cargo/circuits/event-complete/src/main.nr` replaces `circuits/event-complete/src/main.nr`: +19/-56 lines vs live
- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live

## Witnessed behavioral delta (task: factor the reusable EVENT/1 obligation harness out of event-complete into a new app lib circuits/event-harness (generic CompiledJournal<R,B> + EventPublics + discharge<R,B>); rulebook repoints its CompiledJournal there; event-complete keeps the schema-specific half and calls discharge; the public ABI param stays rulebook_id (only the internal harness API uses posting_program_id). App-side only. Witnessed: structural shape + rewiring; nargo test --workspace green (9 crates incl. the harness accept + 3 obligation-reject tests); the UNCHANGED event-complete Prover.toml still solves (value-preserving); and the cand-0033 kernel/app boundary law still passes with the new crate. Goods-receipt-invoice is the one posting program; no second schema.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
