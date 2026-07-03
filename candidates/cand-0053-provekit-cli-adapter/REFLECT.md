# Reflection: cand-0053-provekit-cli-adapter

Intent: wire native ProveKit CLI verification into the fundraise adapter
Status at reflection: landed
Reflected at: 2026-06-14T09:22:24Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0053-provekit-cli-adapter",
  "evaluated_at": "2026-06-14T09:22:06Z",
  "task": "Wire the Nix-packaged native ProveKit CLI path into the fundraise verifier receipt adapter.",
  "checks": {
    "structure": "pass",
    "scope": "pass",
    "toolchain": "pass",
    "unit": "pass",
    "real_cli_receipt": "pass",
    "real_cli_reject": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "7de9505e26f569d55317595a882b9aec150024173e29a099033d3fadc448d947",
    "traces_sha256": "1b2f094b39656491dbdcb8d14a3cc9e6c42c1e374c515749305f19bdfe41c790",
    "body_sha256": "09f4de33a1c246b1952af4378ae5855a965edcc58771a76476616a33a87d0f38",
    "attestation": "2fb643fa243eed3c42f6393bcf0caf9505eb362df234218d0ee4a802d5891fbd"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
