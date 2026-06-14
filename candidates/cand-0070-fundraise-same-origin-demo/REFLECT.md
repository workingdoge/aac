# Reflection: cand-0070-fundraise-same-origin-demo

Intent: Serve the fundraise static UI and proof API from one localhost origin so the live component can complete in browser environments that block cross-port local fetches.
Status at reflection: landed
Reflected at: 2026-06-14T12:15:46Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0070-fundraise-same-origin-demo",
  "evaluated_at": "2026-06-14T12:15:27Z",
  "task": "Serve the fundraise UI and live proof API from one localhost origin.",
  "checks": {
    "source": "pass",
    "mutant": "pass",
    "unit": "pass",
    "web_build": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "5f4935be80aa760162347ee6db1a602fefc3d3b37692db36e89e7854ccc058a9",
    "traces_sha256": "b79100f1ae780ca86d13cd639e6a8b8a9e7a85e7c47cb30f6d105f98db819b79",
    "body_sha256": "495a2ac03f190719d70b3c36968109a2e9614ea0b548fef31505ed36a296d66e",
    "attestation": "8b8969e1f2d8421631b2c4f686f4bc7cf720628d3d41fcf6b927504063d28e50"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
