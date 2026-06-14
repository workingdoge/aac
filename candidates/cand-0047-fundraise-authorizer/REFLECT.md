# Reflection: cand-0047-fundraise-authorizer

Intent: Add a dependency-free fundraise authorizer runtime/CRE-style workflow seam that verifies fundraise packets, binds the EVM mint authorization fields, and emits a deterministic settlement signing request/receipt for the on-chain authorizer role without touching ProveKit or flake tooling.
Status at reflection: landed
Reflected at: 2026-06-14T07:05:17Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0047-fundraise-authorizer",
  "evaluated_at": "2026-06-14T07:05:00Z",
  "task": "Add a dependency-free fundraise authorizer seam that verifies packets, binds EVM mint authorization, and emits deterministic settlement signing requests/receipts.",
  "checks": {
    "text": "pass",
    "runtime": "pass",
    "corrupt": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "fd64e2ea4a2bcebf03e1ff6115a0d52c95c410abdbe97cf4b954f31c99aca102",
    "traces_sha256": "10a99af96d626093524bcb014720b60d04ac44e6f3d8d8e46525eaaf0e72455c",
    "body_sha256": "686ca0e7547d58cf17281ca48411c4b50c04f931c8e36b4ddaea77473f3700e5",
    "attestation": "c898f0be3211e1f4ec6df12784dab4b13bafa824d0ce5ccae9fe710a4de92ca2"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
