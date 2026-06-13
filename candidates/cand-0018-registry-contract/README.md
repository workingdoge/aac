# cand-0018-registry-contract

The **4/REG root registry** as a deployable Solidity contract at `registry/`
(Foundry) — the layer that turns "we can prove it" into "a chain enforces it."

`Registry.update(namehash, proof, publicInputs)` discharges the TRANSITION/1
verifier contract (3/PROOF §5): **old-root equality** (the concurrency rule),
the **context pin**, and the **proof** via the bb-generated UltraHonk
`HonkVerifier`, then atomically advances the roots, chains `fact_fold`, bumps the
nonce, emits `Updated`. Its refusals are the trust model.

Closes the pipeline end to end:

```
circuits/transition (Noir) → bb prove --oracle_hash keccak → HonkVerifier.sol → Registry.update()
```

The `test/fixtures` carry a **real** TRANSITION/1 proof (keccak oracle) + its 8
public inputs.

## Evidence (`eval-self.sh`, attested)

- present — `Registry.sol` discharges the verifier + the old-root/context
  refusals; the bb `HonkVerifier` + the real 8-input proof fixture are present.
- test — `forge test` green (forge/solc from nixpkgs): **`test_ValidProofUpdatesRow`
  verifies the real proof on-chain** (~3.25M gas) and advances the row;
  `test_StaleUpdateReverts`, `test_TamperedProofReverts`, `test_ContextMismatchReverts`
  enforce the refusals.

Status: open (pre-threshold).
