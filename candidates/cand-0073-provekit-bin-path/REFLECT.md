# Reflection: cand-0073-provekit-bin-path

Intent: Resolve relative ProveKit binary paths before the demo runner switches into the temp circuit workdir.
Status at reflection: landed
Reflected at: 2026-06-14T12:45:35Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0073-provekit-bin-path",
  "evaluated_at": "2026-06-14T12:44:52Z",
  "task": "Resolve relative ProveKit binary paths before the runner switches into the temp circuit workdir.",
  "checks": {
    "source": "pass",
    "unit": "pass",
    "mutant": "pass",
    "scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "d726247ab112a56310173b276fdc550b2adef501e1df3c249a82add0d08964b1",
    "traces_sha256": "ade1228e353f02e3366271c40be0c2d6a3fa5fbaee5953f84fc06b3971121190",
    "body_sha256": "06c62354b2dccb8e41f48721c07281e2eb6ffbd5201e6eecc33f6966b8be62b7",
    "attestation": "4a3edfc038ed9ff6f43a142673c1ebd150f33e836edf186ce8e400c4612295dc"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
