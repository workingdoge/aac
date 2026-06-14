# Reflection: cand-0080-fundraise-stale-runner-state

Intent: Treat missing reconciliation/verifier fields from a live runner response as stale runner state, not a book mismatch.
Status at reflection: landed
Reflected at: 2026-06-14T14:29:41Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0080-fundraise-stale-runner-state",
  "evaluated_at": "2026-06-14T14:29:23Z",
  "task": "Treat accepted legacy runner summaries as stale runner state instead of a book mismatch.",
  "checks": {
    "source": "pass",
    "mutant": "pass",
    "build": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "6ad81501314b12ad33ea45846213634adbf4828d05abde77f4d869152a8ea4bc",
    "traces_sha256": "94a3649a4226a33cb77b332bd302f428f60ca3aeac0bcba8905371f4a3d1213d",
    "body_sha256": "989250c93f33d6d220d50d1512e96c1c2329844da9e30fdf76676cff90f3bb69",
    "attestation": "59c02e6824a2248ecc0562a7ec95a3af67ab264ae5a4918e71d9333db9df6745"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
