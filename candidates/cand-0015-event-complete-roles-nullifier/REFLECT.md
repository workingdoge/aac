# Reflection: cand-0015-event-complete-roles-nullifier

Intent: Grow the EVENT-COMPLETE/1 circuit toward a complete BVR: add role coverage (obligation 2 — Buyer and Supplier present + distinct, participant_set commitment) and the event_nullifier (obligation 9 — one-shot identity H(rulebook, event, parties) derived in-circuit so a replay cannot use a fresh nullifier). Negative tests reject self-dealing, a missing role, and a foreign nullifier; the nullifier is shown event/party/rulebook-distinguishing. Proven end-to-end on macOS (bb verify ok).
Status at reflection: landed
Reflected at: 2026-06-13T17:10:51Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0015-event-complete-roles-nullifier",
  "evaluated_at": "2026-06-13T17:10:33Z",
  "task": "EVENT-COMPLETE/1 + role coverage (obligation 2) + the in-circuit event nullifier (obligation 9, anti-replay): accept a complete receipt; reject self-dealing / missing role / foreign nullifier; nullifier event/party/rulebook-distinguishing; sample witness solves",
  "checks": {
    "obligations": "pass",
    "prove": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "2cfeb6cd7a10b0306a0cf3e665102ecd3fd6a2e0b8a35a35132abdd579f16f11",
    "traces_sha256": "be00bd52e202877fbf2534b20b36b33d6bf08227dbe64a1bba6219dcd1974a08",
    "body_sha256": "06746c37690d268d2eb05b6e30a81f46ba864e254f94a962597df6ebdaf7b9a4",
    "attestation": "024c1307d0acd04dd7ca66f3963acbcf624354ec1ececdcc0670ce42ff084488"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
