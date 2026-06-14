# Reflection: cand-0031-sparse-profile

Intent: Define a sparse finite-basis amount/profile representation: fixed slots of per-basis T-account cells with active flags, basis-id bounds, canonical ordering/uniqueness, zero inactive slots, and target-version consequences; no circuit rewrite yet.
Status at reflection: landed
Reflected at: 2026-06-14T00:14:23Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0031-sparse-profile",
  "evaluated_at": "2026-06-14T00:13:53Z",
  "task": "define SPARSE-CELLS/1, a sparse finite-basis amount profile: fixed per-basis T-account cells with active flags, basis-id bounds, active-prefix canonicalization, strict basis-id ordering, zero inactive slots, active zero-cell rejection, absent-as-zero interpretation, sparse state uniqueness, commitment preimage rules, and target-identity consequences. No circuit rewrite, no domain tags, no R1 allocation.",
  "checks": {
    "profile": "pass",
    "crossrefs": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "7a7f8d28b9185aaee65cc5616d97ed18255e394d1983ea17bb17fd602c5d0956",
    "traces_sha256": "6c083abd3c48ddaf0ac7457cb41715c72a5ab59228e655322f20c90c460f1976",
    "body_sha256": "fd8c4cf80ce80c2386cd094337adb5ff29ef6466047e8d402f23262a6cc77b0e",
    "attestation": "276a684fb8e7f67cf9b797c5fa21b9391930ac689ee5b6803297f4e93ff526e2"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
