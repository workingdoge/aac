# Reflection: cand-0082-fundraise-variable-batch

Intent: Make the fundraise demo keep one fill fixed and let the second fill vary up to the order cap through the runner packet path.
Status at reflection: landed
Reflected at: 2026-06-14T14:59:58Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0082-fundraise-variable-batch",
  "evaluated_at": "2026-06-14T14:59:39Z",
  "task": "Keep one fundraise fill fixed while making the second fill variable up to the 150-unit order cap.",
  "checks": {
    "source": "pass",
    "runner": "pass",
    "mutant": "pass",
    "build": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "e06067946d27c89c40072accc9eb6ca96cc11e285765ef566334d2da558663f4",
    "traces_sha256": "43a12d016b5b0a4ef8055ab35080fbfbda365e3ed36bdccddddaa497767acb93",
    "body_sha256": "2f8c4a97590494f5fa79b05e1e6e161324d179109f9af83994ed34cda05090b7",
    "attestation": "4f72b56882a571c6db416d24ea9ac208a9bf3e8667a7e09dbafaf0a834306465"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
