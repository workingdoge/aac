# Reflection: cand-0054-fundraise-demo-runner

Intent: add a one-command ProveKit fundraise demo runner
Status at reflection: landed
Reflected at: 2026-06-14T09:29:13Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0054-fundraise-demo-runner",
  "evaluated_at": "2026-06-14T09:28:56Z",
  "task": "Add a one-command fundraise demo runner that emits a ProveKit live-proof workflow receipt and settlement action.",
  "checks": {
    "structure": "pass",
    "scope": "pass",
    "toolchain": "pass",
    "unit": "pass",
    "cli_help": "pass",
    "real_cli_demo": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "84010025b401748c8e66cf46131467ccb35b41654e7b592815cfee57f17f3529",
    "traces_sha256": "061da6a0157fa7d41200199d872d0697e35e2d981afedda4fd283880d521bee0",
    "body_sha256": "8797145716329a5e99020f88dc52b4404f220862024fe0c6d67540af2092585b",
    "attestation": "f2af4f0092619858810e57e5c74a5a6a6b1b33bcfd1242dc13e668c0f74f268c"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
