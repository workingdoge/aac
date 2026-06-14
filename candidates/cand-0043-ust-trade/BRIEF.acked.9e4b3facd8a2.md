# Threshold Brief: cand-0043-ust-trade

Generated: 2026-06-14T06:33:46Z
Status: validated
Intent: Add a UST cash-trade posting program and demonstrate the capture->novate pipeline COMPOSES. circuits/ust-trade compiles a US Treasury cash trade (seller delivers par, buyer delivers cash) over basis B=2 in the SAME party-grouped chart as novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof (discharge) PLUS a composition conformance test asserting journal_commitment(compile_ust_trade) == journal_commitment(novate::compile_bilateral) AND that novate accepts that very journal -- so capture (EVENT/1) and interposition (NOVATE/1) agree on the leaf (verified concretely: event_ust's journal_commitment 0x06d8c122... equals event_novate's bilateral_commitment 0x06d8c122... at par=1000000/cash=100000000). The most fundamental GSD clearing input, R1 tag 129. App-side: kernel boundary law holds. Witnessed: nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test + existing crates value-preserving), event_ust witness solves, kernel-boundary-check clean, R1 tag 129 recorded.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/ust-trade/Nargo.toml` is NEW at `circuits/ust-trade/Nargo.toml`:        9 lines
- `cargo/circuits/ust-trade/src/lib.nr` is NEW at `circuits/ust-trade/src/lib.nr`:       68 lines
- `cargo/circuits/event-ust/Nargo.toml` is NEW at `circuits/event-ust/Nargo.toml`:       10 lines
- `cargo/circuits/event-ust/src/main.nr` is NEW at `circuits/event-ust/src/main.nr`:      101 lines
- `cargo/circuits/event-ust/Prover.toml` is NEW at `circuits/event-ust/Prover.toml`:        9 lines
- `cargo/sites/ledger/specs/registers/R1.md` replaces `sites/ledger/specs/registers/R1.md`: +1/-0 lines vs live

## Witnessed behavioral delta (task: Add a UST cash-trade posting program (circuits/ust-trade) and demonstrate the capture->novate pipeline composes: the journal is built in the SAME party-grouped chart as novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof (discharge) plus a composition conformance test asserting journal_commitment(ust) == journal_commitment(novate bilateral) and that novate accepts that journal (verified concretely: same 0x06d8c122... commitment across both proofs). R1 tag 129. App-side. Witnessed: structural; nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test); event_ust witness solves; existing crates value-preserving; the cand-0033 boundary law still passes.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
