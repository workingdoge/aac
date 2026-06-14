# Reflection: cand-0051-pedersen-vector-msm-profile

Intent: port the governed ProveKit MSM-only Pedersen vector profile into vnet fundraising
Status at reflection: landed
Reflected at: 2026-06-14T08:18:50Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0051-pedersen-vector-msm-profile",
  "evaluated_at": "2026-06-14T08:18:40Z",
  "task": "Port the ProveKit MSM-only PEDERSEN-VECTOR/1 profile into vnet-fundraising while preserving the existing BN254 reference profile and leaving the prototype circuit unlanded.",
  "checks": {
    "profile": "pass",
    "crossrefs": "pass",
    "scope": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "20bea8047f83b3c05e3f1787bb84f54f2c74a66ace55bf3d0f28981af9bd7da4",
    "traces_sha256": "bb8ab0f34017cd2e7beb822472fd853f3103a6b0a48a485fc2239e9a9eb7c5bf",
    "body_sha256": "6cefe4a500083b9667bb6c6eed2d6b6af329b8f484fde765369ed7978880a8a6",
    "attestation": "4d6f98dde4d6e9b123b643e093d7d6b1f865792f494374ea73cd915c5f9e5e49"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
