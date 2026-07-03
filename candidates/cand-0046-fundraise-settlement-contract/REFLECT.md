# Reflection: cand-0046-fundraise-settlement-contract

Intent: Add a thin authorized-mint settlement contract path for FUNDRAISE-CLEARING/1: runtime emits EVM-shaped mint authorization fields, Solidity verifies signer/round/token/recipient-set/replay, and mints a demo restricted receipt token.
Status at reflection: landed
Reflected at: 2026-06-14T06:45:56Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0046-fundraise-settlement-contract",
  "evaluated_at": "2026-06-14T06:45:33Z",
  "task": "Add runtime EVM mint authorization shaping and a Solidity settlement adapter that verifies authorizer/round/token/recipient-set/replay before minting.",
  "checks": {
    "text": "pass",
    "runtime": "pass",
    "solidity": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "276dbf9767501f32807cb571402cef963af846600415f3106f04c08f77f4b067",
    "traces_sha256": "c1a904203605f3ca179f926e55e7db3f4ae36c68951918c9db75dd8def292842",
    "body_sha256": "d620d0fdcdd1add75b072e8a51f37b7beb608c0088e301c64f58d98d0c4bb61a",
    "attestation": "dbdf50a0c60cdc089623614ecb32df07a9c4b1eba44128b359357f70b1e934d5"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
