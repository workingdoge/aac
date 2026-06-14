# NOVATE/1 — Central-Counterparty Novation

- Name: NOVATE/1 · Status: Raw · **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 3/PROOF, 4/REG.
- Origin: promoted from [Design Note 0004 §3](../../design/0004-clearing-novation-ccp.md).
  Realized by `circuits/novate` (+ `circuits/event-novate`).

This specification defines an **application target** (3/PROOF §4) proving that a
bilateral cleared trade and a pair of central-counterparty legs are a **faithful
novation**: the legs reproduce the two parties' positions and the central
counterparty (CCP) takes **no position** of its own. It is **not** a registry-state
condition: the registry enshrines TRANSITION/1 and trusts whatever its owner proves
(4/REG §5); NOVATE/1 is required only where a **clearing venue** demands it as the
condition of admission to its matched book.

> **The matched-book problem.** A central counterparty's guaranty is sound only if
> its book is *matched* — for every position it takes on one side it holds the
> offsetting position on the other, so it is interposition, not speculation.
> NOVATE/1 makes that a *proof*: the CCP's net across the two legs of a novated
> trade is zero in every dimension. The venue does not have to be trusted to be
> running a matched book; it can prove it — and, with VNET/1, without revealing the
> trades.

## 1. Role and non-redesign boundary

NOVATE/1 composes with the enshrined targets; it does not replace or extend them:

```
EVENT-COMPLETE/1   proves a typed event compiles to its committed journal
NOVATE/1           proves a bilateral journal novates into two CCP-legs (this spec)
NET/1 / VNET/1     prove the CCP's many legs net to the settlement obligations
TRANSITION/1       proves each leg is posted to the committed registry state
```

A **clearing venue** (10/ADMIT) **MAY** require a NOVATE/1 proof as a policy
condition of admitting a trade to its book. The base registry **MUST NOT**: a
registry that gated state on novation would couple itself to a clearing topology
and forfeit 4/REG §5 ("verifies consistency, not truth"). NOVATE/1 introduces **no
new primitive** — it is a balanced decomposition over the same Pⁿ algebra (1/PACI)
the kernel already proves, and its objects are ordinary `journal_commitment` leaves
(3/PROOF tag `TAG_JOURNAL`); it claims **no new domain tag**.

## 2. Objects

Three journals over a shared basis, each a Pⁿ zero-account in the sense of 1/PACI:

- **`J_AB`** — the bilateral cleared trade between parties A and B. It touches only A's
  and B's accounts (it is *bilateral*).
- **`J_AC`** — the leg in which A faces the CCP C.
- **`J_CB`** — the leg in which C faces B.

For a journal `J`, define its **net position grid**

  `net(J)[account][dim] = Σ over that account's rows of (debit − credit)`

a signed vector per account per dimension. (Realized as a `Field` accumulation;
positions are signed, balances are not.)

## 3. Obligations

An instance proves, for the witnessed `(J_AB, J_AC, J_CB)`:

1. **Balanced legs.** `J_AB`, `J_AC`, and `J_CB` are each a Pⁿ zero-account
   (`journal_balanced`).
2. **Genuinely bilateral.** `net(J_AB)[C][·] = 0`: the bilateral does not touch the
   CCP's accounts. (Without this, the C-slice of obligation 3 would not mean
   "matched book".)
3. **Faithful interposition (the one equation).**

   `net(J_AC) ⊕ net(J_CB) == net(J_AB)`  on every account and dimension.

   Read on A's and B's accounts this is **conservation** — their economics are
   exactly the bilateral's. Read on C's accounts, where `net(J_AB)[C] = 0`, it is
   `net(J_AC)[C] + net(J_CB)[C] == 0` — the **CCP is flat** (the matched book at the
   single trade).

## 4. Public ABI

The proof's public inputs are the three journal leaves a venue and registry see:

```
0  bilateral_commitment   journal_commitment(J_AB)
1  leg_ac_commitment      journal_commitment(J_AC)
2  leg_cb_commitment      journal_commitment(J_CB)
```

The circuit recomputes each commitment from the witnessed journal and binds it. A
verifier learns *that these three committed journals are a faithful novation* and
nothing about the amounts — and `J_AC`, `J_CB` are exactly the leaves TRANSITION/1
posts.

## 5. The matched book is a theorem, not an extra assumption

Obligation 3 is one vector equation, and obligation's CCP-flat half is **forced** by
the rest: each leg is a zero-account, so `net(J_AC)` and `net(J_CB)` each sum to 0
across all accounts; once the A- and B-slices equal the bilateral (which itself sums
to 0 over A and B), the C-slice has nowhere to go but 0. A *balanced, faithful*
interposition is *necessarily* flat. NOVATE/1 asserts obligation 2 (bilateral-clean)
explicitly so that "flat" is a statement about the **CCP's** accounts specifically,
not an accounting accident.

## 6. Scope of this version

NOVATE/1 v1 is deliberately the simplest faithful novation:

- **Fixed chart, B=2.** A party-grouped 6-account chart {A, B, C} × {asset, cash} and
  a single-good-vs-cash bilateral. `net_grid` and the obligation are generic in the
  basis B; a richer schema (more dimensions, a multi-line trade) reuses them.
- **No CCP economics.** The CCP is exactly flat — no clearing fee or spread. A fee
  would make CCP-flat a non-trivial (non-zero, witnessed) target rather than a
  theorem; deferred.
- **Canonical legs.** The realization builds the legs by the canonical novation rule
  (as EVENT-COMPLETE/1 builds its journal by Φ_R) and binds their commitments; a
  **venue-submitted-legs** variant (legs witnessed independently, only *checked*
  against the bilateral) is the natural follow-on.
- **One trade.** The **multilateral** net of a CCP's *many* legs into per-member
  settlement obligations is **VNET/1** (amount-vector) and **NET/1** (channel-fact
  closure) — NOVATE/1 is the per-trade interposition those compose over. Fails /
  CNS roll-forward is a TRANSITION/1 carry, out of scope here.

## 7. Realization

`circuits/novate` (lib) provides `net_grid`, the `novate` obligation, and the
canonical `compile_bilateral` / `compile_novation_legs`. `circuits/event-novate`
(bin) is the proof: it witnesses a trade, recomputes the three commitments, binds
them to the public ABI, and discharges `novate`. The kernel/app boundary law
(`tools/kernel-boundary-check.sh`) holds — `novate` is app-side, over the kernel's
`pacioli` and `ledger` primitives, and no kernel crate learns about counterparties.
