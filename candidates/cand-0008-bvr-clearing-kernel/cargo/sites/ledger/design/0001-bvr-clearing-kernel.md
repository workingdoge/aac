# Design Note 0001 — The BalancedVectorReceipt: a Pⁿ Clearing Kernel

- Status: **non-normative design sketch** (NOT an RFC; takes no permanent number)
- Editor: Arjun Velagapudi
- Touches: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET; informs future 9/PROV, 10/ADMIT, 12/OTC
- Provenance: records a design conversation, 2026-06-13

> **One line.** TRANSITION/1 proves balanced posting. BVR/1 proves the posting
> was the canonical compilation of an attested event. NET/1 proves cross-row
> fact closure. VNET/1 proves confidential amount-vector clearing across
> receipts.

This note is a non-normative sketch. It does not change any specification. It
records an architecture for *schema-complete clearing receipts* and fixes the
narrow waist — the `BalancedVectorReceipt` — so that later work can decide
whether it becomes a 9/PROV object, a 10/ADMIT clearing primitive, or a new
application-target specification.

## 1. The correction: clearing is vector, not scalar

The naïve reading of a clearing layer is scalar: *Alice +$10,000, Bob −$10,000,
sum = 0*. That is wrong for AAC. Following Ellerman, the primitive is not a
scalar value claim but a **transaction zero-account in the vector Pacioli group
Pⁿ**: ordered pairs of non-negative n-vectors over a fixed basis of
incommensurable dimensions, balanced *component by component*. A valid
transaction is a zero-account added to a ledger; `Beginning Ledger + Journal =
Ending Ledger` preserves the accounting equation because zero plus zero is zero.

The decisive distinction:

```
AMMs                clear token balances
A scalar layer      clears monetary claims
AAC                 clears multi-dimensional transaction zero-accounts
```

A basis dimension might be `USD_cents`, `USDC_units`, `fabric_meters`,
`garment_units`, `labor_hours`, `carbon_kg`, `invoice_claims`,
`custody_units`, `share_units`. A posting to an account is a T-account of
non-negative vectors `[dₐ ∥ cₐ]` with `dₐ, cₐ ∈ ℕⁿ`. A journal `J = { [dₐ ∥
cₐ] }` is **balanced** iff, for every dimension `j`,

```
Σₐ dₐ,ⱼ = Σₐ cₐ,ⱼ          (the zero-account condition)
```

— USD cancels with USD, fabric meters with fabric meters, nothing collapsed
through price.

## 2. What AAC already proves (the invariant core)

This is not new mathematics for AAC; it is the existing core, stated plainly:

- **1/PACI §1** fixes the default profile as **vectors ℕ^B** of atomic units
  over a finite basis B with a declared bound N.
- **1/PACI §6** forbids the numeraire collapse: *valuations are application-layer
  views and MUST NOT enter enshrined targets — no price oracle enters the trust
  base.* Incommensurability is doctrine, not preference.
- **`Core.lean`** (`sites/ledger/statements`) realizes exactly this: `Amount :=
  Basis → ℕ`, `Term := { debit, credit }`, `pacioliEqual` pointwise over the
  basis, and `K(Amount)` as the Grothendieck completion — i.e. the vector
  Pacioli group Pⁿ — machine-checked with zero `sorry`.
- **`circuits/pacioli`** (`pacioli_equal`, `journal_balanced`) are the in-circuit
  faces of those statements, **per-basis**; **`circuits/transition`**
  (TRANSITION/1) discharges `begin + posted = end` per account per basis, then
  journal balance, with a real UltraHonk proof.

So AAC *already* refuses unbalanced Pⁿ state and already preserves
incommensurate dimensions. **The new design work is schema-complete clearing
receipts — not adding vector balance.**

## 3. The canonical object: BalancedVectorReceipt

The shared clearing object is not a scalar note. It is a **proof-carrying 2/FACT
Event** whose private witness compiles to a Pⁿ transaction zero-account:

```
BalancedVectorReceipt {
  rulebook_id                  # which Φ_R compiler / event-schema law set
  event_schema_id              # the typed event (2/FACT §6 Event)
  dimension_basis_commitment   # the basis B this receipt is denominated in
  account_schema_commitment    # the account/chart shape
  participant_commitments      # the parties and their roles
  journal_commitment           # commits the private vector journal J
  event_nullifier              # 2/FACT §3 factId-as-nullifier; one-shot
  proof                        # the BVR/1 application proof (§5)
}
```

It asserts: *there exists a private vector journal J such that J was generated
from the required event schema, all required parties approved their views, and
the aggregate journal is a zero-account in Pⁿ.* Obligation notes do not vanish,
but they become **projections/outputs** of a vector journal; the journal is the
primitive, the note is a view.

## 4. The Φ_R compiler — completeness, not just balance

Parties must not submit arbitrary balanced journals: **fraud can balance.**
Completeness comes from *deriving* the journal from a canonical, typed event
schema. Let `Φ_R` be the deterministic rulebook compiler:

```
J = Φ_R(E, q, evidence, roles)
```

— event type `E`, private quantities `q`, evidence roots, and role assignments
compile to the vector journal `J` (plus its emitted facts and nullifiers). This
is the soundness/completeness move: *do not only check that the journal
balances; compile it from a typed event schema and prove the compiled journal
is a zero-account.*

`Φ_R` is where AAC's existing pieces already point: 2/FACT §6 Events (typed
legs per party, mutual attestations over the whole event), §5 adapters
(`adapt : Artifact → [Fact]`, deterministic, total-or-rejecting), and §3
`factId` as the nullifier preimage. The projection model is literally 2/FACT
§6: *adapters derive each participant's facts from the event's legs.*

## 5. Layered architecture and the proof separation

```
1. 2/FACT Event
   typed legs, attestations, evidence roots, event id

2. Φ_R compiler  (the rulebook)
   Event + quantities + roles + evidence  →  vector journal J + facts + nullifiers

3. BVR/1  (a.k.a. EVENT-COMPLETE/1)        — APPLICATION target
   J = Φ_R(E, q, evidence, roles)
   ∀ dimension j:  Σₐ dₐ,ⱼ = Σₐ cₐ,ⱼ        (Pⁿ zero-account)
   dₐ,ⱼ, cₐ,ⱼ ≥ 0  and  < MAXⱼ              (non-negativity + carrier bound)
   all required roles present; required approvals/signatures exist
   each party's submitted view is a projection πᵢ(J)
   facts / nullifiers / commitments correctly derived
   event_nullifier = H(rulebook, event, evidence, parties)

4. TRANSITION/1                            — ENSHRINED target (3/PROOF §4.1)
   each participant posts its projection πᵢ(J):
   L_old → L_new  with  begin + posted = end, per account, per basis

5. 5/NET                                   — epoch fact closure (3/PROOF §4.3)
   emitted channel facts net to zero by message identity over ℤ[X]

6. VNET/1  (later)                         — receipt-level amount netting
   committed debit/credit vectors net to zero per dimension,
   via per-dimension Pedersen generators (§7)
```

The three proofs are deliberately separated. The posting proof (4) is often
single-party and need not live inside the BVR coSNARK (3). The
registry/nullifier proof (5, and 4/REG enforcement) prevents
double-financing/settlement/pledging and replay.

## 6. Placement doctrine: Φ_R is an application target, not enshrined

`Φ_R` schema-completeness **MUST NOT** be pushed into TRANSITION/1.
TRANSITION/1 stays the minimal registry-trusted surface:

```
private balanced vector journal + old committed state
  → new committed state + emitted facts + nullifier updates
```

This is exactly 3/PROOF doctrine: the registry enshrines a tiny trusted surface
(three targets); everything else is an **application target** — useful,
versioned the same way, but never a condition of registry state by default
(3/PROOF §4). 4/REG §5 is explicit that the registry *verifies consistency, not
truth.*

But completeness should not live *only* in the evidence layer either, because
fraud can balance. The clean middle:

```
evidence / attestations    prove who claimed what          (2/FACT §8)
BVR/1 (application)         prove schema-relative completeness + Pⁿ balance
TRANSITION/1 (enshrined)    prove Pⁿ balance and row posting
NET/1 (epoch)               prove cross-row fact closure
```

A lender, market, clearing venue, or admissibility layer (10/ADMIT) **MAY
require** `BVR/1` as policy. The base registry **MUST NOT**. The slogan:

> AAC core refuses unbalanced state. Application targets refuse incomplete
> commercial receipts. Evidence layers grade truth.

## 7. Two nettings, kept distinct

5/NET and the proposed VNET/1 are different invariants and MUST NOT be conflated:

```
5/NET (today)            channel-fact netting over ℤ[X]
                         push/pull facts cancel by message identity
                         ("every pull matched by a push")

VNET/1 (later)           amount-vector netting over Pⁿ
                         debit/credit dimensions cancel by committed
                         basis generators ("USD with USD, fabric with fabric")
```

VNET/1 uses a **Pedersen vector commitment** with one generator per basis
dimension — and this is the *correct* home for additive homomorphism (the
Merkle-root/fold hashing inside the circuits should use Poseidon2, which is
~48× cheaper and where homomorphism is irrelevant; see §8). For a posting `a`:

```
Cᴰₐ = Σⱼ dₐ,ⱼ·Gⱼ + rₐᴰ·H        Cᶜₐ = Σⱼ cₐ,ⱼ·Gⱼ + rₐᶜ·H
```

with `G_USD, G_fabric_meters, G_garment_units, …` distinct generators — so
dollars and meters **cannot** cancel by sharing a scalar field. The generator
basis encodes Ellerman's incommensurates cryptographically. Aggregating,

```
Σₐ Cᴰₐ − Σₐ Cᶜₐ = (Σ d − Σ c)·G + (Σ rᴰ − Σ rᶜ)·H
```

so a zero-account collapses the value part and leaves a **pure-blinding point**
— a native, out-of-circuit balance/netting check across many receipts without
re-proving. The full per-dimension check (with non-negativity, range, schema,
roles) still lives in the BVR coSNARK; the homomorphism buys *native aggregation*
across receipts/epochs, which is precisely the VNET job. Whether
`pedersen-vector/1` later becomes an admitted 5/NET accumulator for
receipt-aware epochs is deferred.

## 8. The hash-primitive split (folds in the measured tradeoff)

Two different jobs, two primitives:

| job | primitive | why |
|-----|-----------|-----|
| in-circuit Merkle roots / folds (TRANSITION/1, BVR/1) | **Poseidon2** | measured ~48× cheaper than `pedersen_hash` in UltraHonk (≈75 vs ≈3,586 gates per 2:1 hash); homomorphism is irrelevant because the hash compresses the curve point to a field and is *not* additively homomorphic |
| native cross-receipt / cross-epoch amount netting (VNET/1) | **Pedersen vector commitment** (per-dimension `Gⱼ`) | homomorphism is load-bearing and encodes incommensurability; computed off-circuit |

The earlier "keep Pedersen because it is homomorphic" instinct was right about
the *commitment* and wrong about the *hash*: `pedersen_hash` (the x-coordinate)
is collision-resistant but not homomorphic, while `pedersen_commitment` (the
curve point) is. Use each where it belongs.

## 9. The security boundary

`Φ_R` proves **schema-relative completeness, not truth.** It can prove:

```
all required roles for this schema are present
the event canonically compiles to this vector journal
the journal is balanced in Pⁿ
the emitted facts and nullifiers are correct
the evidence roots are bound
```

It cannot prove:

```
the fabric physically existed
the warehouse did not lie
the invoice was commercially fair
there was no side agreement
the legal claim is enforceable everywhere
```

Those stay in provenance (9/PROV), grading (11/GRADE), admissibility (10/ADMIT),
policy, bonding, and law. This respects 2/FACT §8 (*attestation ≠ truth*) and
1/PACI §8 (a scoped, once-only identification is a **right**, not a module
relation — expressed as event legs consumed by nullifiers, never a quotient).

## 10. Open questions

1. **Where BVR/1 lands.** A 9/PROV commercial object, a 10/ADMIT clearing
   primitive, or a standalone application-target spec? Stabilize the narrow
   waist (this note) first; choose the home later.
2. **Rulebook governance.** `Φ_R` is a deterministic, content-addressed rulebook
   (like a 2/FACT TypeDecl). Who governs the schema set, and how is a deployed
   `rulebook_id` registered (cf. 4/REG §4 target governance, the Deployment
   Register R1)?
3. **coSNARK fit.** BVR/1's witness is distributed across counterparties; a
   collaborative SNARK (co-noir, already in the toolchain) is the natural prover.
   But co-noir's default is 3-party honest-majority — bilateral (N=2) 8/SESS
   sessions have no honest majority, needing either dishonest-majority 2PC (~2×)
   or an external non-counterparty helper node. Confirm co-noir v0.7.0 can
   compile the u64/blackbox circuit before committing.
4. **VNET/1 vs 5/NET admission.** Whether `pedersen-vector/1` becomes an admitted
   5/NET accumulator, or stays a separate receipt-level target.
5. **12/OTC interaction.** Collateral is a posting, not a promise (12/OTC);
   scenario/margin units are basis dimensions. How does BVR/1 carry contingent
   legs and collateral encumbrance as Pⁿ dimensions?
