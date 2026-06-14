# Threshold Brief: cand-0039-second-posting-program

Generated: 2026-06-14T05:32:17Z
Status: validated
Intent: Add a SECOND posting program to validate that the cand-0037 EVENT/1 harness (circuits/event-harness) is genuinely schema-agnostic, not accidentally fit to goods-receipt-invoice. New app lib circuits/bom-receipt compiles a bill-of-materials / materials-kit receipt (a garment maker buys fabric+thread+trim from a supplier against USD) over basis B=4 with DENSE debit/credit vectors -- vs rulebook's B=3 single-good trade -- so discharge<R,B> is exercised at a different B and journal shape with the IDENTICAL harness glue. New bin circuits/event-bom-receipt is a near-clone of event-complete differing ONLY in the schema-specific half (4-quantity Event, its event_commitment at a distinct R1 tag 126, Phi_P with B=4); the schema-agnostic obligations route through the same discharge call. DOCTRINE: a kit RECEIPT (exchange), not an assembly TRANSFORM -- the harness requires a per-dimension zero-account, which an exchange (each good conserved, cash the other way) satisfies but a transform (incommensurable inputs -> different output) cannot (1/PACI Ellerman vector Pacioli). App-side only: kernel boundary law holds. Witnessed: nargo test --workspace green (bom_receipt 2/2 + event_bom_receipt 6/6 incl. a B=4 unbalanced-journal rejection + the existing crates value-preserving), event_bom_receipt witness solves, kernel-boundary-check clean, R1 tag 126 recorded.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/bom-receipt/Nargo.toml` is NEW at `circuits/bom-receipt/Nargo.toml`:        9 lines
- `cargo/circuits/bom-receipt/src/lib.nr` is NEW at `circuits/bom-receipt/src/lib.nr`:      133 lines
- `cargo/circuits/event-bom-receipt/Nargo.toml` is NEW at `circuits/event-bom-receipt/Nargo.toml`:        9 lines
- `cargo/circuits/event-bom-receipt/src/main.nr` is NEW at `circuits/event-bom-receipt/src/main.nr`:      117 lines
- `cargo/circuits/event-bom-receipt/Prover.toml` is NEW at `circuits/event-bom-receipt/Prover.toml`:       14 lines
- `cargo/sites/ledger/specs/registers/R1.md` replaces `sites/ledger/specs/registers/R1.md`: +9/-0 lines vs live

## Witnessed behavioral delta (task: Add a SECOND posting program to validate the cand-0037 EVENT/1 harness is schema-agnostic. circuits/bom-receipt compiles a bill-of-materials / materials-kit receipt over basis B=4 (vs rulebook B=3) with dense Dr/Cr vectors; circuits/event-bom-receipt is a near-clone of event-complete routing the schema-agnostic obligations through the IDENTICAL discharge call. A kit RECEIPT (exchange, per-dimension zero-account) not an assembly TRANSFORM (incommensurable dimensions cannot offset, 1/PACI). Distinct R1 event tag 126 (event_commitment does not bind program_id). App-side; kernel boundary law holds. Witnessed: structural (B=4 schema + harness reuse + workspace + R1 tag); nargo test --workspace green (bom_receipt 2/2 + event_bom_receipt 6/6 incl. a B=4 unbalanced-journal rejection); event_bom_receipt witness solves; existing event_complete/transition/nullify still solve (value-preserving); the cand-0033 boundary law still passes.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
