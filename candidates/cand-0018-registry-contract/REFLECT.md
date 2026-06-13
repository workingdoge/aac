# Reflection: cand-0018-registry-contract

Intent: The 4/REG root registry as a deployable Solidity contract at registry/ (Foundry): Registry.sol implements the TRANSITION/1 update rule -- old-root equality (the concurrency rule), context pin, proof discharge via the bb-generated UltraHonk verifier, atomic root advance + fact_fold chaining + nonce. Verifies the REAL TRANSITION/1 proof on-chain (keccak oracle). forge test green: valid proof advances the row; stale/tampered/context-mismatch refused. Closes the pipeline circuit -> bb proof -> solidity verifier -> registry.
Status at reflection: landed
Reflected at: 2026-06-13T17:55:09Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0018-registry-contract",
  "evaluated_at": "2026-06-13T17:54:56Z",
  "task": "4/REG Registry.sol verifies the real TRANSITION/1 UltraHonk proof on-chain and advances the row; refuses stale-root / tampered-proof / context-mismatch updates (forge test, bb-generated HonkVerifier)",
  "checks": {
    "present": "pass",
    "test": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "8c509c576c20a03791de240c8ed05d10fba9ec7d04e05dedac95257b6213a013",
    "traces_sha256": "43e2c13030178335d87065fc1b194fa5a1026e17291d302d064aff328662a1b8",
    "body_sha256": "a4078cdb2123aa61f33429956aae77dd96b06a8255e5ad700ccaf37ef4da8951",
    "attestation": "eea3af373ea855cefadc929f930439acc31f36889fc1fbcd35b68a130a032dac"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
