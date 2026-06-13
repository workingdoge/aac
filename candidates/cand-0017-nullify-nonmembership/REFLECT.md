# Reflection: cand-0017-nullify-nonmembership

Intent: NULLIFY/1 (3/PROOF S4.2) at circuits/nullify: prove non-membership + insertion into the consumed-nullifier set via the indexed low-leaf range bracket over a strictly-sorted invariant (Field ordering by bn254::lt) — the historical-set anti-replay guard. ABI [first_root,last_root,sequence_commitment,count]. Composition: consumes a fresh EVENT-COMPLETE/1 event_nullifier and REJECTS replaying a spent one. Proven end-to-end on macOS (bb verify ok). Bound: one insertion, sorted-array fold root; production = binary indexed Merkle with succinct path proofs.
Status at reflection: landed
Reflected at: 2026-06-13T17:43:14Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0017-nullify-nonmembership",
  "evaluated_at": "2026-06-13T17:43:02Z",
  "task": "NULLIFY/1 non-membership via the low-leaf range bracket over a strictly-sorted set — accept a non-member; reject an already-spent value / wrong low-leaf / tampered root; consume a fresh EVENT-COMPLETE/1 event_nullifier and reject replaying a spent one; sample witness solves",
  "checks": {
    "logic": "pass",
    "prove": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "f9156574909b2d7f61031321bd36cd529bc4a9bb761881b25d79c341590aa7f2",
    "traces_sha256": "e9729e8301b553562ce6df3ff7776861f209cd3e817f85f30f96240f32b8c280",
    "body_sha256": "a0426503580d824761eb93f30edda3bc088d415d2418e2b855c05d5843188609",
    "attestation": "a24241d1fcae3610d47965c5e358117de72b12782460d29465ca225c71c24d87"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
