# Reflection: cand-0023-nullify-registry

Intent: Wire the enshrined NULLIFY/1 target into 4/REG: the registry maintains a per-row historical nullifier-SET root (the strictly-sorted consumed-nullifier set, TAG_SET) advanced by advanceNullifier(namehash, proof, publicInputs[4]) which discharges a SECOND pinned bb verifier (NullifyHonkVerifier) over the NULLIFY/1 ABI [first_root,last_root,sequence_commitment,count] -- old-set-root equality (the concurrency rule), count==1, and the proof. This is the historical anti-replay guard on-chain, distinct from TRANSITION/1's batch-local insertion-chain nullifier_root (different representation: TAG_SET sorted-set fold vs TAG_NULLIFIER insertion chain), so no transition circuit/fixture change. EVENT-COMPLETE/1 is NOT wired (4/REG S5: the base registry MUST NOT require it). Real NULLIFY/1 keccak-oracle proof verifies on-chain in forge; stale set root / tampered proof / count!=1 refused.
Status at reflection: landed
Reflected at: 2026-06-13T19:56:50Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0023-nullify-registry",
  "evaluated_at": "2026-06-13T19:56:31Z",
  "task": "wire the enshrined NULLIFY/1 target into 4/REG: a per-row historical nullifier-set root advanced by advanceNullifier, discharging a second pinned bb verifier (NullifyHonkVerifier) over a real keccak-oracle NULLIFY/1 proof on-chain; stale set root / tampered proof / count!=1 refused; EVENT-COMPLETE/1 NOT enshrined (4/REG S5); both verifiers + Registry under EIP-170; forge test green (8); Deploy runs",
  "checks": {
    "present": "pass",
    "onchain": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "fc412e01dec8d88f568ab5761860d9a96f76648903a5c8132d508aa1cbc7b83a",
    "traces_sha256": "22e163d467dba877ba55bfbd79872a42c05261db0265573ba8cb867aa6632993",
    "body_sha256": "198b1ce9d0f4e677b2919ba28dc3c39c38fef3bd70bf033ff9c2c28b32460f59",
    "attestation": "263f4bbc10a275c92c5d4579c8c543b40de323f16b3541314f52ee8afba02387"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
