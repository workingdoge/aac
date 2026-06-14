# Reflection: cand-0042-bcc-settlement-boundary

Intent: Clarify BCC as an agreement certificate with authenticated ECDH and cancellation opening, separating it from private-state settlement proofs and bridge contracts.
Status at reflection: landed
Reflected at: 2026-06-14T05:46:28Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0042-bcc-settlement-boundary",
  "evaluated_at": "2026-06-14T05:45:52Z",
  "task": "Clarify BCC as an agreement certificate with authenticated ECDH and cancellation opening, separating it from private-state settlement proofs and bridge contracts.",
  "checks": {
    "text": "pass",
    "runtime": "pass",
    "vectors": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "9c0a4bee19c3e2e80bf016d3795a79cf8206879350cc25a1ce71824695d1761e",
    "traces_sha256": "252b9d09212c0318fe648966878446b71954eb7f39fb5bf1d6c6969a7084ec75",
    "body_sha256": "58ff98fb1046f56600e7153b3c365caadecee8524b0b5d6599248ab4266fa33a",
    "attestation": "51b25b31d812458aa1983f1bb98632d201cfffe9f7de38f001c2ae71c7f02a73"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
