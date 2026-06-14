# Reflection: cand-0045-vnet-runtime-adapter

Intent: Add a dependency-free JS VNET-BN254/link verifier, wire fundraise-runtime to use it by default, and add a BCC cancellation verifier seam for non-mock profiles.
Status at reflection: landed
Reflected at: 2026-06-14T06:24:44Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0045-vnet-runtime-adapter",
  "evaluated_at": "2026-06-14T06:24:21Z",
  "task": "Add JS VNET-BN254/link reference verification, fundraise default VNET verification, and BCC cancellation adapter fail-closed behavior.",
  "checks": {
    "text": "pass",
    "vnet_runtime": "pass",
    "bcc_runtime": "pass",
    "fundraise_runtime": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "0390374325ff0cb06400bbd851b6c8aac27161109b9c4c317badc78157ae84ac",
    "traces_sha256": "96d3ecced37ae585d294f749f671a012034427d18c5809b3e8f428510bc6f554",
    "body_sha256": "c032c1798ae3db4a3918800adf7d925fd1833f834b0c1ac06e0fbb873211d94f",
    "attestation": "0896c6b6ee73ddc80a101412268fc28658716e22f6f956092efdb8e7836594aa"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
