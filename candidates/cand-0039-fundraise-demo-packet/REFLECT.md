# Reflection: cand-0039-fundraise-demo-packet

Intent: Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker that bind round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; include rejection fixtures for price, settlement, token, and VNET failures.
Status at reflection: landed
Reflected at: 2026-06-14T03:34:05Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0039-fundraise-demo-packet",
  "evaluated_at": "2026-06-14T03:33:53Z",
  "task": "Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker binding round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; reject price, settlement, token, and VNET failures.",
  "checks": {
    "text": "pass",
    "vectors": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "8b0da81da75c00d11b8962470b2abe4f614c88b5d7423e91e4e12e7929017926",
    "traces_sha256": "5dc523fc3ba6f7c4463801195db9ab5896206eefb38a9e633b350a2da521a315",
    "body_sha256": "09ed09d09484c97970d43cf4c186d8bfd476c6c26224aab88e49e744c0d86a10",
    "attestation": "6217b672712d20f3e7d7d1ef1e5fd06160339326b3d89dddcb9fdf0515d725ac"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
