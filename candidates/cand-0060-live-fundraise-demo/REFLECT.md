# Reflection: cand-0060-live-fundraise-demo

Intent: Add a live localhost fundraise demo API and frontend control that runs the ProveKit fundraise proof on demand while keeping the captured receipt as fallback.
Status at reflection: landed
Reflected at: 2026-06-14T11:00:40Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0060-live-fundraise-demo",
  "evaluated_at": "2026-06-14T11:00:15Z",
  "task": "Add a live localhost fundraise demo API and frontend control while preserving the captured receipt fallback.",
  "checks": {
    "runner_server": "pass",
    "frontend_source": "pass",
    "web_build": "pass",
    "landing_scope": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "5dd85ac5dcad9560b14c33ab01c2e5e382fefd5a82c60fdab35111673fa63909",
    "traces_sha256": "7db68a8ed12ef21ba7b719cf3fb6f903cec3001832e8dedd8a4bc76aadf944bf",
    "body_sha256": "15298d13c91e4fbbabf6e31f484bba1f7d37354e712164bd0ff07e07013eaac8",
    "attestation": "61f23eac0f1583738a23df2e0018b134df26cd9c0163e072d7aef23b4696d973"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
