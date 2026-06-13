# Reflection: cand-0019-registry-deployable

Intent: Make the 4/REG registry actually deployable: the bb HonkVerifier is 24,644B runtime (68 over EIP-170) at optimizer_runs=200 — drop to 50 (23,782B, 794 under) so it deploys on a real EVM, correctness unchanged (forge test still green). Add registry/script/Deploy.s.sol (deploys the verifier + auto-links its ZKTranscriptLib + the Registry pinned to it); verified deploying to live anvil under EIP-170 (ONCHAIN EXECUTION SUCCESSFUL).
Status at reflection: landed
Reflected at: 2026-06-13T18:09:30Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0019-registry-deployable",
  "evaluated_at": "2026-06-13T18:09:19Z",
  "task": "make the 4/REG registry deployable — HonkVerifier under EIP-170 at optimizer_runs=50, forge test still green (real proof verifies), and the Deploy script deploys+links the verifier library + Registry",
  "checks": {
    "present": "pass",
    "deployable": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "c57f079723e93d5c98e242c911b4f190d5a0ba58dd684c9fbbf855b7aeae4d41",
    "traces_sha256": "68b0c8dd79b7294ef6f6a4aec9fb5ec3b55078d59d9458f29254046bf5fdc853",
    "body_sha256": "954e54ab2a038a83b1e32f7f2a0ea395733d12672686b15ea383a3ad701945af",
    "attestation": "5945c87ce109a8beb01861f71f8ad422165726c1891a8099afd39f99d54cff5c"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
