# Reflection: cand-0049-provekit-receipt-adapter

Intent: Add a dependency-free ProveKit verifier receipt adapter that normalizes accepted ProveKit WHIR/Groth16 proof results into fundraise-workflow verifier receipts, allowing require_live_proof workflows without touching flake/Nix dependencies.
Status at reflection: landed
Reflected at: 2026-06-14T07:25:51Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0049-provekit-receipt-adapter",
  "evaluated_at": "2026-06-14T07:25:30Z",
  "task": "Add a dependency-free ProveKit verifier receipt adapter for fundraise-workflow live-proof authorization.",
  "checks": {
    "text": "pass",
    "runtime": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "32bd8db0a28d1dfb038daafdd0ea61c050e447deda41168084b5fe6e5859fc5a",
    "traces_sha256": "a77a875d870bfb2f8239b03c5f10796d71b35bf994c4bf7d5476ec5f1729087e",
    "body_sha256": "f9217e44aa001709668828b983240c42c049764b94ece0ec4019637d3e5509bc",
    "attestation": "65e36a2c030afffd2647a0ccda346c418dd9b6e598803141bc9a38c50ecb3fde"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
