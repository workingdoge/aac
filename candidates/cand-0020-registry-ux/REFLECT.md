# Reflection: cand-0020-registry-ux

Intent: A /registry page + aac-row Lit component surfacing 4/REG: the proof-native ledger Row advancing from a TRANSITION/1 proof (real roots prev->next, nonce 0->1, the verifier-contract discharge checklist, the Updated event), tying the on-chain registry to the /circuit proof. Registered in elements.ts, sidebar-linked, verified live in the preview.
Status at reflection: landed
Reflected at: 2026-06-13T18:17:14Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0020-registry-ux",
  "evaluated_at": "2026-06-13T18:17:03Z",
  "task": "aac-row component + /registry page — registers, token-themed, renders a 4/REG row advancing from a TRANSITION/1 proof (old-root equality, refusals), site builds with it bundled",
  "checks": {
    "register": "pass",
    "theme": "pass",
    "page": "pass",
    "build": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "37682abe6a244da025f71fba7a06c5f723bce4e9145a28a64867e16c08d3f5a7",
    "traces_sha256": "d3c0e33d61bb0daa0a73da0d163d86144e1dae70d5d22509dc7d5f2105b1b072",
    "body_sha256": "7b23f19688d10b9f057b9a7b58d0cd8733facff08903cc8fe7e501e5f8108639",
    "attestation": "6ba45b78f13a3ed7ccec890bfb8527194bcb7d9d3ad02fcbc7e429b2834b2f92"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
