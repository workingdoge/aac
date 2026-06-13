# cand-0025-registry-poseidon-regen

The **cand-0024 cascade, part 1.** The Poseidon2 migration changed every
commitment value, so the registry's bb verifiers and proof fixtures — generated
from the *pedersen* circuits — no longer corresponded to the live circuits. This
regenerates them, restoring circuit↔verifier coherence on-chain.

## What changed

Regenerated from the now-Poseidon2 circuits, all four `bb`-derived artifacts:

- `src/HonkVerifier.sol` — the TRANSITION/1 verifier (new vk: `VK_HASH`
  `0x2283…` → `0x18893…`).
- `src/NullifyHonkVerifier.sol` — the NULLIFY/1 verifier (new vk; public
  contract renamed so the two co-compile).
- `test/fixtures/{transition,nullify}.{proof,pub}` — real keccak-oracle proofs
  carrying the new Poseidon2 commitment values (8 / 4 public inputs).

`Registry.sol`, the tests, `Deploy.s.sol`, and `foundry.toml` are **unchanged** —
the test reads roots from the fixtures, never hard-codes them, so swapping the
artifacts is sufficient.

A side benefit: the Poseidon2 proof is a touch cheaper to verify on-chain —
`test_ValidProofUpdatesRow` gas ~3.27M → ~3.01M.

## Evidence (`eval-self.sh`, attested)

- present — the regenerated verifiers (new vks, not the pre-poseidon
  `0x2283…`) + the four keccak fixtures (transition 8 / nullify 4 public inputs)
  are present.
- onchain — a scratch registry (landed sources + the regenerated artifacts)
  under `forge` (nixpkgs foundry+solc): `forge test` green (**8** — both the real
  TRANSITION/1 and NULLIFY/1 Poseidon2 proofs verify on-chain against the new
  verifiers); both verifiers + the Registry under EIP-170; `Deploy` runs.

Cascade remaining: cand-0026 updates the web components' hard-coded roots to the
new Poseidon2 values.

Status: open (pre-threshold).
