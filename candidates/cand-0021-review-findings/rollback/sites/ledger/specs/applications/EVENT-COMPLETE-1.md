# EVENT-COMPLETE/1 — Schema-Complete Event Compilation

- Name: EVENT-COMPLETE/1 · Status: Raw · **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG.
- Origin: promoted from [Design Note 0001](../../design/0001-bvr-clearing-kernel.md);
  its final home (9/PROV object, 10/ADMIT primitive, or a standalone target) is open.

This specification defines an **application target** (3/PROOF §4) proving that a
private journal is the *canonical compilation of a typed, attested commercial
event* — not merely that it balances. Its proof-carrying object is the
**BalancedVectorReceipt** (BVR). It is **not** a registry-state condition: the
registry enshrines TRANSITION/1 and trusts whatever its owner proves
(4/REG §5); EVENT-COMPLETE/1 is required only where a deployment, market,
lender, or admissibility layer demands it as policy.

> **The fraud-can-balance problem.** A balanced journal is not a complete one.
> Parties could submit arbitrary offsetting entries that net to zero in Pⁿ yet
> correspond to no real event. Completeness comes from *deriving* the journal
> from a canonical, typed event schema: `J = Φ_R(E, q, evidence, roles)`.

## 1. Role and non-redesign boundary

EVENT-COMPLETE/1 composes with the enshrined targets; it does not replace or
extend them:

```
EVENT-COMPLETE/1   proves schema-complete event → journal compilation (this spec)
TRANSITION/1       proves each participant posts its projection πᵢ(J) to its row
NET/1              proves cross-row channel facts net over the epoch
```

A deployment, market, lender, clearing venue, or admissibility layer (10/ADMIT)
**MAY** require an EVENT-COMPLETE/1 proof as a policy condition. The base
registry **MUST NOT**: a registry that gated state on schema-completeness would
couple itself to application semantics and forfeit 4/REG §5 ("verifies
consistency, not truth").

The core responsibilities are unchanged: 1/PACI defines balance as K(M)
class-zero over the default profile ℕ^B; 2/FACT defines facts, event legs,
attestations, and factId/nullifier identity; 3/PROOF enshrines the three
registry targets; 4/REG accepts only proof-gated row updates against pinned
roots. Adding event-schema semantics to TRANSITION/1 would enlarge
target-governance risk, force unrelated rows onto one commercial schema, and
blur that doctrine. EVENT-COMPLETE/1 keeps the enshrined surface minimal by
living outside it.

## 2. The rulebook compiler Φ_R

A **rulebook** R is a deterministic, content-addressed event-to-journal
compiler. Like any 2/FACT type declaration, its identity is the digest of its
canonical encoding: `rulebook_id := H(enc(RulebookDecl))`. Given a typed event,
private quantities, bound evidence, and role assignments, it yields the vector
journal and everything derived from it:

```
Φ_R : (E, q, evidence, roles) ↦ (J, facts, nullifiers)
```

Determinism is normative: two evaluations of the same rulebook on byte-identical
inputs MUST yield byte-identical outputs. The rulebook set and its governance
are a deployment concern (cf. 4/REG §4 target governance, Register R1).

## 3. The BalancedVectorReceipt

The canonical clearing object is a **proof-carrying 2/FACT Event** whose private
witness compiles to a transaction zero-account in Pⁿ:

```
BalancedVectorReceipt := {
  receipt_version:      typeId      # this target version
  rulebook_id:          typeId      # the Φ_R compiler (§2)
  event_schema_id:      typeId      # the typed event (2/FACT §6)
  event_commitment:     scalar      # commitment to E
  participant_set:      scalar      # parties and their roles
  basis_commitment:     scalar      # the basis B this receipt is denominated in
  account_schema:       scalar      # the chart/account shape
  journal_commitment:   scalar      # commits the private vector journal J
  fact_fold:            scalar      # 3/PROOF Annex B, over emitted facts
  fact_count:           uint
  nullifier_commitment: scalar      # over the event's one-shot nullifiers
  evidence_root:        scalar      # binds the referenced evidence (7/DATA)
  proof_target_id:      targetId    # = H(enc(this TargetDecl)), 3/PROOF §2
  proof_public_inputs:  [scalar]    # the ABI vector of §5
  proof:                bytes
}
```

Obligation notes do not vanish; they become **projections** of the journal
(§6.2). The journal is the primitive; a note is a view.

## 4. The statement

> There exist a private typed event `E`, private quantities `q`, evidence
> references, role attestations, and a canonical vector journal `J` such that
> `J = Φ_R(E, q, evidence, roles)`, `J` is a transaction zero-account in Pⁿ, all
> roles the schema requires are present, every amount coordinate is non-negative
> and within the profile bound, all emitted facts and nullifiers are correctly
> derived, and every public commitment is recomputed from the witness.

### Obligations (normative)

A conforming EVENT-COMPLETE/1 instance MUST enforce, in-circuit:

1. **Canonical event.** `E` encodes under 2/FACT §2 (`cjson/1`); the witnessed
   bytes are exactly `enc(E)`.
2. **Role coverage.** Every role `event_schema_id` requires under `rulebook_id`
   is present, exactly as R demands — no missing party, no unauthorized extra.
3. **Attestation.** The attestations cover `enc(E)` (or the declared commitments
   to it) per 2/FACT §6; assent is to the whole event, not a single leg.
4. **Canonical compilation.** `Φ_R(E, q, evidence, roles)` deterministically
   yields `(J, facts, nullifiers)`; the witnessed `J` is that output.
5. **Pⁿ zero-account.** For every basis dimension `j`, `Σₐ dₐ,ⱼ = Σₐ cₐ,ⱼ`
   (1/PACI §3). No dimension is settled in another; no numeraire is introduced
   (1/PACI §6).
6. **Carrier bounds.** Every coordinate `dₐ,ⱼ, cₐ,ⱼ` is non-negative and below the
   profile bound (the `Field → u64 → Field` discipline of 3/PROOF Annex C;
   soundness of the per-dimension sums is `journal_sum_field_sound`).
7. **Event binding.** Every emitted fact includes the event id wherever 2/FACT §6
   requires it.
8. **Fact fold.** `fact_fold` is recomputed over the emitted facts' `factId`s in
   canonical (journal) order (3/PROOF Annex B).
9. **Nullifiers.** Each one-shot nullifier is correctly derived from its
   `factId` (2/FACT §3) and the receipt's nullifiers are pairwise distinct.
10. **Recomputation.** `journal_commitment`, `basis_commitment`,
    `nullifier_commitment`, `evidence_root`, and every public commitment are
    recomputed in-circuit and equated to the claimed inputs. Pass-through inputs
    bound only by external context MUST be marked `unconstrained` in §5.

## 5. Public ABI (order normative)

| # | name | notes |
|--:|------|-------|
| 0 | `rulebook_id` | the Φ_R compiler; `unconstrained` (bound by deployment policy) |
| 1 | `event_schema_id` | the typed event schema; `unconstrained` |
| 2 | `event_commitment` | recomputed from `enc(E)` |
| 3 | `participant_set` | recomputed; role coverage proven (§4.2) |
| 4 | `basis_commitment` | recomputed; pins the dimension basis B and its order |
| 5 | `journal_commitment` | recomputed (order-binding) |
| 6 | `fact_fold` | recomputed, Annex B |
| 7 | `fact_count` | |
| 8 | `nullifier_commitment` | recomputed over the one-shot nullifiers |
| 9 | `evidence_root` | binds referenced evidence (7/DATA); `unconstrained` |

As in all targets (3/PROOF §3, §5), an `unconstrained` input is meaningful only
through the verifier's context check; here that context is deployment policy and
the attested rulebook/schema/evidence resolution, not registry state.

## 6. Composition

### 6.1 Three proofs, separated

```
1. EVENT-COMPLETE/1   attested event → canonical vector journal → Pⁿ zero-account
2. TRANSITION/1       each participant posts πᵢ(J):  Lᵢ_old → Lᵢ_new, begin+posted=end
3. NET/1 (+ 4/REG)    cross-row fact closure; old-root equality; nullifier progression
```

The posting proof (2) is often single-party and need not live inside the
EVENT-COMPLETE coSNARK. A collaborative SNARK (coSNARK) is appropriate for (1)
**only** when the witness is genuinely distributed and private (multilateral
events, confidential cross-ledger equality, private exposures); a bilateral
event whose terms both parties already know MAY instead use signatures over the
commitments plus an ordinary single-prover proof. coSNARKs are for private
multiparty computation, not a universal proving mode.

### 6.2 Projections

Each participant's ledger update posts its projection of the same journal:
`Lᵢ_new = Lᵢ_old + πᵢ(J)`. This is exactly the 2/FACT §6 adapter deriving a
participant's facts from the event's legs — the parties post projections of one
shared zero-account, not independently-matching entries.

### 6.3 Amount-vector netting (VNET, future)

Where confidential amount netting across many receipts is wanted, a future
VNET/1 target (or an admitted 5/NET accumulator) uses **Pedersen vector
commitments** with one generator per basis dimension —
`C = Σⱼ vⱼ·Gⱼ + r·H` — so a batch is balanced iff `Σ Cᴰ − Σ Cᶜ = R·H` opens to
a pure blinding `R`. This is distinct from 5/NET (channel-fact netting over
ℤ[X], by message identity) and from the in-circuit hashing of this target
(which uses a circuit-native hash; the commitment's homomorphism is irrelevant
to a Merkle root and is reserved for native cross-receipt netting). A conforming
vector-commitment profile MUST bind generator derivation and basis order to
`basis_commitment` and `profileId`, admit no known discrete-log relation among
`H` and any `Gⱼ`, enforce amount ranges before or inside the proof, represent
signed amounts as non-negative debit/credit vectors (never negative field
elements), forbid mixing basis declarations or profile versions in one receipt,
and require a zero-opening (aggregate-blinding) proof rather than inspection of
an arbitrary group point.

## 7. Security considerations

EVENT-COMPLETE/1 proves **schema-relative completeness, not truth.** It can
prove role coverage, canonical event→journal compilation, componentwise Pⁿ
balance, bounded non-negative coordinates, and one-shot nullifier derivation. It
**cannot** prove the physical existence of the goods, the honesty of a
warehouse, the commercial fairness of an invoice, the absence of an off-registry
side agreement, the correctness of any valuation, or legal enforceability. Those
remain with provenance (9/PROV), grading (11/GRADE), admissibility (10/ADMIT),
bonding, policy, and law. This preserves 2/FACT §8 (*attestation ≠ truth*) and
1/PACI §8 (a scoped, once-only identification is a **right** consumed by a
nullifier — never a module quotient).

The target line:

> AAC core refuses unbalanced state. Application targets refuse incomplete
> commercial receipts. Evidence layers grade truth.

## Annex A — Domain tags

EVENT-COMPLETE/1's in-circuit hash invocations carry leading tags from the
application range (3/PROOF Annex A, 120–255), assigned first-come via 1/C4 patch
and recorded in the Deployment Register (R1) before use, never in this text.
