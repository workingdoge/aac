# Reflection: cand-0056-fundraise-demo-summary

Intent: Add a presentation-grade summary artifact for the fundraise ProveKit-to-settlement demo runner.
Status at reflection: landed
Reflected at: 2026-06-14T09:59:32Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0056-fundraise-demo-summary",
  "evaluated_at": "2026-06-14T09:59:13Z",
  "task": "Add a deterministic presentation summary artifact to the fundraise demo runner.",
  "checks": {
    "structure": "pass",
    "scope": "pass",
    "unit": "pass",
    "cli_help": "pass",
    "summary_projection": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "f973e83fdbad4c747fe1b3354828fd1e5377b7b976b5a296b8e03625e6e8d7be",
    "traces_sha256": "7802e420af798842b827c9063dbd01dfc102bb474aba37530e8dd063fb01f6aa",
    "body_sha256": "173f7f00a6f3833920aa17f0f6ea0fe1ace5ea8733be2dd6ef75861b4f0399c0",
    "attestation": "eeccee0f823c85e57c72f6ad1d3915dd7b089a63e0c3bf2afcf8015c727b5ca3"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
