# Reflection: cand-0083-fundraise-balance-sheet-proof

Intent: Add a live ProveKit balance-sheet before/after proof to the fundraise demo, tied to the selected batch.
Status at reflection: landed
Reflected at: 2026-06-14T15:43:16Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0083-fundraise-balance-sheet-proof",
  "evaluated_at": "2026-06-14T15:42:49Z",
  "task": "Add a separate live ProveKit proof for the fundraise balance sheet before and after the selected batch.",
  "checks": {
    "source": "pass",
    "runner": "pass",
    "circuit": "pass",
    "mutant": "pass",
    "build": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "f096cbe3408ba5891897e5544e24d598fa7645a1f34a4228596acf5e469da655",
    "traces_sha256": "16c05ee18211577d085bc1ea955e78c66c711896fe1511e21db2b6e57d168c42",
    "body_sha256": "a2421ba26ea126c1dd281f582d5986b6a9eb98cdfe6a9148df2778ebdbdb90a7",
    "attestation": "e34b1ae5aad7b321b6ee87606ad76a15f27911cb39dfe03b96842b4a32367694"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
