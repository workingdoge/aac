# Reflection: cand-0043-ust-trade

Intent: Add a UST cash-trade posting program and demonstrate the capture->novate pipeline COMPOSES. circuits/ust-trade compiles a US Treasury cash trade (seller delivers par, buyer delivers cash) over basis B=2 in the SAME party-grouped chart as novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof (discharge) PLUS a composition conformance test asserting journal_commitment(compile_ust_trade) == journal_commitment(novate::compile_bilateral) AND that novate accepts that very journal -- so capture (EVENT/1) and interposition (NOVATE/1) agree on the leaf (verified concretely: event_ust's journal_commitment 0x06d8c122... equals event_novate's bilateral_commitment 0x06d8c122... at par=1000000/cash=100000000). The most fundamental GSD clearing input, R1 tag 129. App-side: kernel boundary law holds. Witnessed: nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test + existing crates value-preserving), event_ust witness solves, kernel-boundary-check clean, R1 tag 129 recorded.
Status at reflection: landed
Reflected at: 2026-06-14T06:33:47Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0043-ust-trade",
  "evaluated_at": "2026-06-14T06:32:23Z",
  "task": "Add a UST cash-trade posting program (circuits/ust-trade) and demonstrate the capture->novate pipeline composes: the journal is built in the SAME party-grouped chart as novate::compile_bilateral, so the journal EVENT/1 captures is byte-identical to the bilateral NOVATE/1 novates. circuits/event-ust is the EVENT/1 proof (discharge) plus a composition conformance test asserting journal_commitment(ust) == journal_commitment(novate bilateral) and that novate accepts that journal (verified concretely: same 0x06d8c122... commitment across both proofs). R1 tag 129. App-side. Witnessed: structural; nargo test --workspace green (ust_trade 1/1 + event_ust 5/5 incl. the composition test); event_ust witness solves; existing crates value-preserving; the cand-0033 boundary law still passes.",
  "checks": {
    "logic": "pass",
    "prove": "pass",
    "boundary": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "5f91ba13f09eaf787b4976ae130d06c261284dcff177e0172f2df0db170575c8",
    "traces_sha256": "4f30765a78e4a4f95ccb10e6259eeeeadd857e61f7f3a0f95be3ea015a163eca",
    "body_sha256": "792d62bb74a23539828c72367579360c1734596041ece492a350279b6f7df04d",
    "attestation": "6881df049d7fcd1e6a2f38a2d29aaa4b0f98176650fa52efd55aa7b5f22e97df"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
