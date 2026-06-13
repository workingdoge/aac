# Threshold Brief: cand-0013-phi-rulebook

Generated: 2026-06-13T16:51:56Z
Status: validated
Intent: A Phi_R event-to-journal compiler for the goods-receipt-invoice schema, landed as circuits/rulebook (lib crate, depends on pacioli): compile_goods_receipt_invoice(event) deterministically emits the vector journal, closing 'fraud can balance' — the journal is the schema's image, not arbitrary entries. Proven: it reproduces the cand-0009 conformance vector exactly, and compiles to a P^n zero-account for ALL quantities (each posted once Dr, once Cr). Realizes EVENT-COMPLETE/1 obligations 4 (canonical compilation) + 5 (zero-account) for one schema.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/rulebook/Nargo.toml` is NEW at `circuits/rulebook/Nargo.toml`: 7 lines
- `cargo/circuits/rulebook/src/lib.nr` is NEW at `circuits/rulebook/src/lib.nr`: 93 lines

## Witnessed behavioral delta (task: Phi_R goods-receipt-invoice compiler — reproduces the Pⁿ conformance vector exactly and compiles to a zero-account for all quantities (the journal is the schema image, not arbitrary entries); workspace compiles with the rulebook crate)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
