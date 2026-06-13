# 5/NET — Epoch Netting

- Name: 5/NET · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG.

Rows are independent; the one condition that crosses them is **channel
balance**: every pull matched by a push, globally (1/PACI §4). This
specification defines how that condition is demonstrated once per epoch.

## 1. Epochs

An **epoch** is a contiguous range of registry history, delimited by
`fold` checkpoints: `fold_begin` is the chained fact_fold state at epoch
open, `fold_end` at close. Epoch boundaries are set by the registry on a
fixed schedule declared in `context`.

## 2. Admissible accumulators

The netting statement requires a **multiset** accumulator over emitted
facts. Admissible constructions:

- `ecmh-grumpkin/1`: Σ hash-to-curve(factId, side-signed) on the embedded
  curve; balance ⟺ identity element.
- `logup-committed/1`: a logUp-style rational accumulation whose random
  challenge is derived in-circuit from a prior commitment to the complete
  fact multiset (commit-then-challenge; self-supplied randomness is
  admissible only under this two-phase structure).

A plain field-sum of digests is **prohibited**: field addition of hash
outputs is not collision-resistant as a multiset hash, and an adversary
can forge balancing sets against it.

## 3. The epoch proof

A NET/1 instance (3/PROOF §4.3) proves: the facts whose order-binding fold
connects `fold_begin` to `fold_end` form a multiset whose net in ℤ[X] is
zero. On verification (under the full verifier contract, with
`fold_begin`/`fold_end` pinned to the registry's checkpoints) the registry
records `epochs[e].balanced := true` and emits `Netted(e)`.

`balanced` is monotone per epoch and carries exactly this meaning: **every
cross-entity claim consumed within the epoch was produced within or before
it.** It does not assert solvency, truth of attestations, or anything
about unclosed epochs.

## 4. Rings

Multilateral netting (A→B→C→A) requires no special mechanism: a ring is
balanced iff its facts net to zero, which the epoch proof checks uniformly.
Novation — replacing legs with a composite — is an application-layer act
(reserved 10/ADMIT) that MUST be expressed as ordinary facts: pulls
retiring the legs, a push creating the composite, all within one epoch.

## 5. Security considerations

Accumulator choice is consensus (§2); challenge derivation in
`logup-committed/1` MUST be commit-then-derive or the construction is
void; epoch length trades liveness of the `balanced` signal against proof
size and SHOULD be stated with the deployment's threat model. Because
NET/1 verifies once per epoch, the verification constant is economically
negligible here; netting cadence, not proof cost, is the binding variable
(4/REG Annex C).
