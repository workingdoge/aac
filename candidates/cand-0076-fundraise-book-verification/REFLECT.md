# Reflection: cand-0076-fundraise-book-verification

Intent: show issuer book verification after the private order fill
Status at reflection: landed
Reflected at: 2026-06-14T13:31:56Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0076-fundraise-book-verification",
  "evaluated_at": "2026-06-14T13:31:43Z",
  "task": "Show post-swap issuer book verification in the private order-fill demo.",
  "checks": {
    "source": "pass",
    "mutant": "pass",
    "build": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "cf8a6528b54e8a62ddd7467476551ab3cbd80f927f5717a1b35a965426d6a5c4",
    "traces_sha256": "823c18928cf86aa2222577f7700f2cb6715cef3c87e85f3a8a160a98b1498e76",
    "body_sha256": "5353f6fbdd6f38a6fd57cc17a57ef8ea11afca87a8542d811c93b578cf7c07b0",
    "attestation": "ae616e7d729ca4ecae6330a55cf582d33444240799466dc670220315bea63572"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
