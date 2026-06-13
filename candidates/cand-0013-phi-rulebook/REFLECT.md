# Reflection: cand-0013-phi-rulebook

Intent: A Phi_R event-to-journal compiler for the goods-receipt-invoice schema, landed as circuits/rulebook (lib crate, depends on pacioli): compile_goods_receipt_invoice(event) deterministically emits the vector journal, closing 'fraud can balance' — the journal is the schema's image, not arbitrary entries. Proven: it reproduces the cand-0009 conformance vector exactly, and compiles to a P^n zero-account for ALL quantities (each posted once Dr, once Cr). Realizes EVENT-COMPLETE/1 obligations 4 (canonical compilation) + 5 (zero-account) for one schema.
Status at reflection: landed
Reflected at: 2026-06-13T16:51:57Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0013-phi-rulebook",
  "evaluated_at": "2026-06-13T16:51:46Z",
  "task": "Phi_R goods-receipt-invoice compiler — reproduces the Pⁿ conformance vector exactly and compiles to a zero-account for all quantities (the journal is the schema image, not arbitrary entries); workspace compiles with the rulebook crate",
  "checks": {
    "derives": "pass",
    "test": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "007d9eecc26c8be0cea98d511c70a515a7ce4eac8536bed376a360d8fa3d380b",
    "traces_sha256": "f29b89eaeceafe4c1a29c56c952e04d09a9cfbed25a88acc7e94104106b79eda",
    "body_sha256": "0f31e863d480b5e57b6853a60da1f6351449372e9f5c6d8fa92958c9908e2830",
    "attestation": "acd0d5985a8bb79a3c3e05dc08696aa26f75f1ffa52e283332252081ccb9792c"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
