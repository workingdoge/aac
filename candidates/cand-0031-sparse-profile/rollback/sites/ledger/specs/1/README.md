# 1/PACI — Ledger Semantics

- Name: 1/PACI · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later (specification text). RFC 2119 key words apply.
- Lifecycle: 2/COSS. Changes: 1/C4.

This specification defines the meaning of balance. It defines no bytes, no
cryptography, and no protocol; every other specification in this suite
cites it for semantics.

## 1. Amount domains

An **amount domain** is a commutative monoid M that is **cancellative**
(a + c = b + c ⟹ a = b). A **profile** instantiates M; the default profile
is vectors ℕ^B of atomic units over a finite **basis** B, with a declared
**bound** N such that every coordinate of every admitted amount is < N.

Implementations MUST reject amounts outside the profile bound at every
ingestion and witness boundary. Rationale: cancellativity and the bound are
jointly what make §2 sound when evaluated in a finite field (3/PROOF §4).

## 2. Terms and the Pacioli group

A **term** is an ordered pair (debit, credit) ∈ M × M.

The **Pacioli relation**: (d₁,c₁) ≈ (d₂,c₂) ⟺ d₁ + c₂ = c₁ + d₂.

For cancellative M this is an equivalence; the quotient **K(M)** is the
Grothendieck completion of M (the Pacioli group). The class of (d,c) is
written [d − c]. A term is **balanced** iff its class is zero, equivalently
iff d = c.

Implementations MAY decide class equality by either of two procedures, and
MUST agree with both:
(a) the Pacioli relation directly (cross-addition);
(b) reduced normal forms: the unique representative with pointwise-disjoint
support (min(d,c) = 0 coordinatewise), compared for equality.

The **residual** of a term is its reduced normal form. Residual reporting
MUST be exact and MUST have disjoint support.

## 3. Journals

A **journal** is a finite multiset of terms ("rows"). Its **class** is the
sum of row classes. A journal is **balanced** iff its class is zero.

Required laws (conformance properties):
- **Permutation invariance**: verdicts and residuals are functions of the
  multiset, not of any ordering.
- **Additivity**: class(J₁ ⊎ J₂) = class(J₁) + class(J₂).
- **Locality option**: a profile MAY additionally require **entry balance**
  (each row, or each tagged entry group, is itself balanced). Entry balance
  implies journal balance; the converse is false. A profile MUST state
  which predicate it enforces.

## 4. Channels

Let X be a set of **messages**. A **channel fact** is an oriented
occurrence (side ∈ {push, pull}, message ∈ X, multiplicity ∈ ℕ₊) on a named
channel. Facts on a channel form the free commutative monoid on X, taken
twice (pushes, pulls); the **net** of a fact log is its image in the free
abelian group ℤ[X].

A log is **balanced** iff its net is zero — per message, pushes equal
pulls. Residuals MUST be exact nets with disjoint support. Multiplicity
zero or negative MUST be rejected.

Channels and journals are the same construction at different types:
ℤ[X] = K(free commutative monoid on X). A conforming implementation MUST
NOT maintain two balance semantics; both MUST reduce to one congruence.

Messages need not be cash-typed. A holder's claim and an issuer's
outstanding obligation are a push/pull pair on a channel whose message
*is the claim*: "my claim is your obligation" generalizes "my credit is
your debit". Mirror invariants between ledgers (holder/issuer,
obligor/obligee) are therefore channel balance, not a new primitive.
Likewise, issuance capacity is conservation, not a side constraint:
model authorized-but-unissued as an account and the charter's law
*authorized = issued + unissued* is ordinary balance (informative).

## 5. Rights

A **right** is an entitlement that does not stack: granting it twice
confers it once; consuming it twice is invalid. The natural algebra of
rights is idempotent, and Grothendieck completion annihilates idempotents
(a + a = a ⟹ [a] = 0). Therefore:

- Rights MUST NOT be modeled as amounts.
- A right is identified by a canonical identity (2/FACT). Consumption is
  recorded by a **nullifier** derived from that identity.
- A consumption log is **valid** iff its nullifiers are duplicate-free and
  every consumed right was granted.

## 6. Valuation

A **valuation** is a homomorphism V : K(M) → A out of the Pacioli group
(prices applied to property vectors). Valuations are application-layer,
plural by design (cost, tax basis, last round, fair value are *different
maps*), and informative: the books are the vector, a valuation is a view.
Valuations MUST NOT appear in enshrined targets — no price oracle enters
the trust base. The ratio at which properties exchange is witnessed by
the transaction's mutually attested legs (2/FACT §6), never asserted by
an internal valuation.

## 7. Conformance

A conforming implementation agrees with this specification's verdicts,
residuals, and laws on all inputs of its profile. Informative reference
artifacts: an executable property suite testing kernel agreement with an
independent K(M) model, and a mechanized statement of §2–§5 in a
proof assistant. Normative force rests in this text.

## 8. Security considerations

Two semantic hazards live at this layer. **Conflation of rights with
amounts** (§5): any chart containing a non-stacking entitlement as a
quantity is unsound by construction and MUST be rejected in review.
**Exchange relations as quotients**: modeling a witnessed exchange
(e.g. 1000·USD − 1·Share) as a module relation and checking balance in
M/⟨ρ⟩ is unsound — a quotient identifies the entire ℤ-span of ρ, so a
once-agreed exchange licenses every integer multiple of itself, and
quotients cannot be scoped to a transaction. A scoped, once-only
identification is a *right*, not a relation: express the exchange as
event legs (2/FACT §6) whose application is consumed by nullifiers (§5).
All other hazards (encoding collisions, field overflow) arise at the
layers that realize this semantics and are specified there.
