# cand-0024-poseidon2-migration

**PERF.** Migrates the circuits' commitment hash from `pedersen_hash` to a
**Poseidon2** sponge — the headline gate reduction on the pedersen-dominated
proving cost.

## What changed

A new shared `circuits/hash` crate exposes `poseidon_hash<let N>([Field; N]) ->
Field`: a sponge (t=4 / rate=3 / capacity=1) over the stdlib
`std::hash::poseidon2_permutation`. The capacity lane is initialized with the
input length so different arities can't collide; the existing domain tags
(`TAG_JOURNAL`, `TAG_SET`, …) ride in the input unchanged.

> **Which Poseidon2:** Aztec's — the canonical Noir stdlib permutation. Only the
> *sponge wrapper* is AAC's (the stdlib's canonical `Poseidon2::hash` sponge is
> private in beta.14). Zero external dependencies — the permutation
> (round constants, MDS) is the audited part; the sponge is small and sound.

All **18** `pedersen_hash` sites are swapped: `ledger` (4), `rulebook` (1),
`transition` (7), `nullify` (6). `event-complete` and `pacioli` are unchanged —
`event-complete` inherits Poseidon2 through `ledger`/`rulebook`. Commitment
**values change by design** (this intentionally breaks cand-0016's byte-identity
— that was the pre-migration invariant), so the `transition`, `nullify`, and
`event-complete` `Prover.toml`s are regenerated to the new values.

## The number

| circuit | pedersen | poseidon2 |
|---|--:|--:|
| one 2:1 hash | ~3,586 gates | ~94 (padded) / ~75 (raw perm) |
| **TRANSITION/1** (whole circuit) | **40,511** | **7,535** |

~48× per hash; **~5.4× on the whole transition circuit** (it was
pedersen-dominated). ACIR opcodes 775 → 673.

## Downstream (follow-ups)

The commitment values changing cascades: the **registry** proof fixtures +
both bb verifiers regenerate (next candidate), and the **web** components'
hard-coded roots update (after). This candidate is circuits-only and leaves the
workspace fully coherent (`nargo test` + `nargo execute` green).

## Evidence (`eval-self.sh`, attested)

- logic — the Poseidon2 sponge is in the `hash` crate; all four crates are free
  of `pedersen` and call `hash::poseidon_hash`; the workspace + per-crate deps
  are wired.
- prove — a scratch workspace (landed pacioli/event-complete + the migrated
  crates): `nargo test` green across all 7 crates (36 tests), the regenerated
  `transition`/`nullify`/`event-complete` witnesses solve, and (bb present) the
  transition gate count collapses below 12,000 (measured 7,535, was 40,511).

Status: open (pre-threshold).
