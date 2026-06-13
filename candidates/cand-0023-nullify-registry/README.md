# cand-0023-nullify-registry

Wires the **enshrined NULLIFY/1 target** (3/PROOF §4.2) into the on-chain **4/REG
registry** — turning "the registry consumes the nullifier" into "…and provably
hasn't been consumed before, against history."

## What it does

The registry now pins a **second** bb UltraHonk verifier (`NullifyHonkVerifier`)
and maintains a per-row **historical consumed-nullifier SET root**
(`Row.nullifierSetRoot`). A new `advanceNullifier(namehash, proof, publicInputs)`
discharges the NULLIFY/1 verifier over its ABI `[first_root, last_root,
sequence_commitment, count]`:

- **old-set-root equality** — `publicInputs[0]` must equal the row's set root
  (the same concurrency rule `update` uses for account/nullifier roots);
- **single-insertion bound** — `count == 1`;
- **the proof** — a real keccak-oracle NULLIFY/1 proof, verified on-chain;

then advances the set root to `last_root` and emits `NullifierAdvanced`.

## Why a separate path (not folded into `update`)

The two nullifier roots are **different representations**: TRANSITION/1's
`next_nullifier_root` is an *insertion-chain* accumulator (`TAG_NULLIFIER`) that
enforces only batch-local distinctness; NULLIFY/1's is a *strictly-sorted set*
fold (`TAG_SET`) that proves *historical* non-membership. They are not
interchangeable, and 3/PROOF separates them into two targets — so the registry
enshrines both, side by side, with **zero change to the transition circuit or its
fixture** (no cascade). Binding a transition's consumption to a NULLIFY insertion
atomically (one combined update) is the natural next step.

**Doctrine:** EVENT-COMPLETE/1 is **not** wired in — 4/REG §5 says the base
registry MUST NOT require an application target (it verifies consistency, not
truth). The contract records this boundary in a comment.

## Two verifiers, one project

`bb write_solidity_verifier` emits a contract named `HonkVerifier` with internal
libraries (`ZKTranscriptLib`, …). Those libraries are **file-scoped**, so two
verifier source units coexist; only the public `contract` is renamed
(`HonkVerifier` → `NullifyHonkVerifier`) so the test/Deploy can import both.
Both verifiers (23,782 / 23,779 B) and the `Registry` (2,824 B) stay under
**EIP-170**; only the `Deploy` *script* is large, and a script is never deployed.

## Evidence (`eval-self.sh`, attested)

- present — `advanceNullifier` + pinned `nullifyVerifier` + `nullifierSetRoot` +
  old-set-root/`count==1` refusals + the 4/REG §5 boundary + the renamed verifier
  + the 4 nullify tests + the real fixtures + the Deploy wiring are all present.
- onchain — a scratch registry (landed + cargo overlays) under `forge` (nixpkgs
  foundry+solc): `forge test` green (**8** tests — the real NULLIFY/1 proof
  verifies and advances the set root; stale set root / tampered proof /
  count!=1 refused; the TRANSITION/1 path unchanged); both verifiers + the
  Registry under EIP-170; `Deploy` runs (deploys both verifiers + the Registry).

Status: open (pre-threshold).
