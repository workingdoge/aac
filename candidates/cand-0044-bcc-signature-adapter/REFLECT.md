# Reflection: cand-0044-bcc-signature-adapter

Intent: Add a BCC signature adapter seam with canonical typed-data payloads and make Noir composition explicit through transcript/context commitments rather than in-kernel wallet verification.
Status at reflection: landed
Reflected at: 2026-06-14T06:11:33Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0044-bcc-signature-adapter",
  "evaluated_at": "2026-06-14T06:11:13Z",
  "task": "Add a BCC signature adapter seam and keep Noir composition explicit through transcript/context commitments.",
  "checks": {
    "text": "pass",
    "bcc_runtime": "pass",
    "fundraise_runtime": "pass",
    "adapter_policy": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "3652f0bf26c8448a149a36436c98db0e0a3fa47380f52455766df84659468212",
    "traces_sha256": "b9c9b3bbfe8e61daae10b7e2b3d3f75448e8bb959f326072790c5d88f2a9fe91",
    "body_sha256": "84b06b21ca35b37cb38cbb27d5c42d4cee9320b89be023e05b3f08c59f1850e4",
    "attestation": "40a42beff2ad510dd72f6626eff6fd9c959b48500494069044e9a5c7f5bb7f5f"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
