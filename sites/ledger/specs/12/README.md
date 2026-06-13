# 12/OTC — Margined Bilateral Contingent Contracts

- Name: 12/OTC · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies.
- Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET.

Two parties enter a contract whose legs are contingent on an attested
outcome, posting partial escrow and carrying the remainder as **margined
exposure backed by their own provable books**. Escrow secures a contract;
books secure a counterparty. This specification defines the contract
object, the encumbrance mechanism that makes margin safe, the
underwriting protocol between parties, settlement, and default
semantics. It is an application profile of the suite: it adds **no new
trust machinery** — only postings, facts, rights, and claims that the
core specifications already define.

## 1. The central mechanism: encumbrance as a posting

A party does not *promise* collateral; it **posts** it. To margin an
exposure of E under contract `cid`, the party applies an ordinary
journal entry moving E from its free-reserves cell to a dedicated cell:

    debit  encumbered:cid / asset   E
    credit reserves       / asset   E

and updates its registry row with a TRANSITION proof whose journal
contains this entry.

**Proposition (no rehypothecation).** Amounts are valued in ℕ
(1/PACI §1) and every post-state cell is constrained into the profile
bound by the transition target (3/PROOF §3, carrier injectivity — which
in particular enforces non-negativity). Therefore a party with R free
reserves cannot encumber more than R in total across any number of
contracts: a second encumbrance of the same funds would drive the
reserves cell below zero, no satisfying witness exists, no transition
proof can be produced, and the registry row cannot advance.
*Double-pledging is not forbidden; it is arithmetically infeasible.*

**Corollary (solvency claims are unnecessary for margin).** The
counterparty does not need a "reserves ≥ X" range claim. A verified
row update whose journal demonstrably contains the encumbrance entry
**is** the solvency proof for this exposure: you cannot post what you
do not have. Underwriting reduces to verifying that the encumbrance
happened, on-registry, bound to this contract.

## 2. Objects

### 2.1 Contingent event

```
ContingentEvent := Event ⊕ {
  condition: {
    attestor:  typeId        # oracle attestation scheme (2/FACT §3)
    market:    Value         # what is being decided
    outcomes:  [ o₁ … oₖ ]
    expiry:    timestamp     # after which the contract is voidable
  }
  legsByOutcome: outcome → [ Leg ]   # settlement legs per outcome
  margin: {
    escrowBps:   uint        # portion prefunded (e.g. 2000 = 20%)
    exposure:    party → amount      # remainder carried on books
  }
}
```

Both parties' attestations cover `enc(ContingentEvent)` (2/FACT §6):
assent is to the *entire* contingent structure — condition, every
outcome's legs, and the margin terms.

### 2.2 Facts at each phase

| phase | facts posted (both parties unless noted) |
|-------|------------------------------------------|
| formation | push `contingent(cid)` on the contracts channel; encumbrance entry per §1 |
| settlement | pull `contingent(cid)`; settlement legs of the realized outcome; encumbrance release/consumption |
| default (loser, absent) | none — which is the point: the unmatched pull and the stranded encumbrance remain visible |

The right to settle `cid` is a 1/PACI §5 right (nullifier preimage:
the settlement fact's identity); settlement is one-shot per contract.

## 3. Underwriting protocol

A request–response exchange between parties; every check is a
machine-dischargeable predicate.

```
A → B : RFQ(market, size)
B → A : Terms[ fullEscrow | margin(escrowBps, requirements) ]
A     : posts encumbrance entry; updates row (nonce n → n+1)
A → B : Acceptance package
B     : underwrites (table below); countersigns or refuses
A,B   : escrow deposits (§4); contract ACTIVE
```

**Acceptance package:** the ContingentEvent (A-signed), A's row
coordinates (entityId, nonce n+1), the TRANSITION proof's public
inputs, and a cell claim opening `encumbered:cid = exposure_A` against
the new root. Note the encumbered cell's value equals the already-known
exposure, so this opening discloses nothing beyond the contract's own
terms.

**Underwriting predicate table (B MUST check all):**

| # | predicate | discharged by |
|--:|-----------|---------------|
| 1 | row state matches: `get(entityId_A).nonce = n+1`, roots match the proof's outputs | registry read |
| 2 | the row update verified on-registry under a pinned TRANSITION target | 4/REG §2 (the registry did this; B confirms the event) |
| 3 | `encumbered:cid = exposure_A` under the new root | cell-claim verification per the 3/PROOF §5 contract |
| 4 | encumbrance is bound to *this* contract | `cid` in the cell key; `cid = H(enc(ContingentEvent))` |
| 5 | no disqualifying open residuals on A's row | residual scan (§6) against B's policy |
| 6 | condition is well-formed: attestor typeId is acceptable to B; expiry sane | local policy |

Symmetrically for B's exposure. A party MAY skip margin and demand
full escrow; the protocol degenerates gracefully.

**Staleness.** Predicate 1 binds the package to row nonce n+1; any
intervening update changes the nonce and the package MUST be refused
and re-issued. The race window is one registry read.

## 4. Escrow

An escrow instance holds the prefunded portion only. Abstract
interface (the concrete contract and chain are deployment profile):

```
deposit(cid, party, amount)        # both sides, escrowBps of stake
recordOutcome(cid, outcome, att)   # attestor-gated, once
withdraw(cid)                      # per legsByOutcome[outcome], escrow portion
refund(cid)                        # only after expiry with no outcome,
                                   # or on mutually signed VoidEvent
```

The escrow never holds the margined remainder and never reads books;
it is deliberately dumb. The outcome attestation it stores is the
boundary attestation (2/FACT §8) that both ledgers cite when posting
settlement legs — origination-boundary truth enters the system exactly
here, through a multiply-attested scheme identified by typeId, and
nowhere else.

## 5. Settlement

On `recordOutcome(cid, o)`:

1. Escrow portions distribute per `legsByOutcome[o]` (anyone may call).
2. Both parties post the settlement entries: pull `contingent(cid)`;
   the loser's `encumbered:cid` converts to payment (an asset transfer
   plus the corresponding book entry); the winner's `encumbered:cid`
   releases to reserves. The remainder transfer is a single ordinary
   payment Event referencing `cid`.
3. Settlement facts consume the contract's rights; a second settlement
   attempt is a nullifier collision and MUST be rejected everywhere.

**State machine:**

```
PROPOSED → ACTIVE → SETTLING → SETTLED
              │          └────→ DEFAULTED   (remainder unpaid past T_settle)
              └→ VOID  (expiry with no outcome, or mutual VoidEvent)
```

## 6. Default and the credit fixed point

If the loser does not complete step 5.2 within `T_settle`:

- the winner keeps the full escrow distribution (the guaranteed floor);
- the loser's row permanently exhibits: an **unmatched pull** on the
  contracts channel and a **stranded encumbrance** cell — both visible
  to any future counterparty's predicate 5;
- no further enforcement exists or is needed at this layer.

This is deliberate. Default is not adjudicated; it is *worn*. Because
every future underwriting run reads residuals before margining,
**this contract's residuals are the next contract's risk input**:
margin terms price open residuals, persistent residuals price the
party out of margined trade entirely, and clearing one's residuals is
the only path back. Creditworthiness is not a score assigned by an
authority — it is the machine-checkable absence of unmatched pulls.
Deployments MAY layer bonded or insured tiers above this; the base
layer is reputational physics.

**Loss bound.** A counterparty's maximum loss on a margined contract
is the unescrowed exposure, `(1 − escrowBps)·stake`. Underwriting
policy SHOULD set `escrowBps` per counterparty history (residual
record, settled-contract count), approaching full escrow for strangers
— which recovers, as the zero-history case, exactly the design this
specification generalizes.

## 7. Portfolio margin (scenario mode)

§1's per-contract encumbrance reserves each contract's worst case in
full: safe, simple, and — across a book of positions — capital-blind,
since it cannot net. This section defines the portfolio mode, in which
obligations are booked where they belong and netting is arithmetic.

### 7.1 Contingent units

For a condition with outcome partition {o₁ … oₖ}, each `asset|oᵢ` is a
**distinct basis element**: a typed unit declared per 2/FACT §3
({asset, attestor, market, outcome} → typeId). A claim contingent on oᵢ
is not the asset; it is its own property, exchangeable for the asset
only by attested resolution. Probability never prices these units
anywhere in the enshrined path (1/PACI §6); they convert, they are not
valued.

### 7.2 Booking rule

At formation, each party posts, per outcome, its net payout under that
outcome: obligations as **scenario liability cells**
(`liabilities / asset|oᵢ`), entitlements as the mirrored scenario
claims — and the two parties' postings are push/pull pairs on the
claim channel (1/PACI §4). Offsetting positions on the same partition
move the same cells in opposite directions: **netting is cell
arithmetic**, and the capital a book requires is its net worst case
per outcome, not the gross sum of its contracts.

### 7.3 The generalized proposition (state-wise solvency)

Equity cells are ℕ-valued and bound-constrained per scenario column
(3/PROOF §3). Therefore a party cannot book a scenario liability its
scenario equity cannot absorb: no satisfying witness exists, and the
row cannot advance. *A valid row update with obligations recognized
is, itself, a proof of solvency in every outcome.* §1 is recovered as
the single-scenario degenerate case. Underwriting predicate 3 (§3) is
replaced in this mode by: the counterparty verifies that the row
advanced with the formation entry recognized and that its own mirrored
claim cells match the contract's legs; no cell opening is required
beyond the contract's own terms.

### 7.4 Settlement as conversion

On an attested outcome o*, settlement posts conversion entries citing
the attestation: realized units `asset|o*` convert to the asset 1:1
(liabilities become payable and are settled per §5; claims become
receivable), and unrealized units `asset|oᵢ, i≠*` are extinguished by
release entries citing the same attestation. All conversion entries
consume the contract's settlement right (§5.3): resolution is
one-shot, and a balance sheet cannot carry both a contingent unit and
its resolution.

### 7.5 Limits

The scenario set is the contract's outcome partition. Positions on
*different* conditions inhabit different columns and do not net
against each other; a profile MUST bound the scenario set it supports,
and combining conditions correctly requires joint-state columns —
booking per-condition marginals understates joint worst case under
correlation. Simple profiles (single condition, k ≤ small) are exact;
multi-condition portfolio margin is future work and MUST NOT be
approximated silently.

## 8. Privacy posture (stated, not implied)

Visible to the world: row updates and their public inputs, escrow
deposits and distributions, fact identities (hence the *existence* and
*count* of open contracts), residuals. Visible to the counterparty
only: the ContingentEvent's terms, legs, and the encumbered cell's
opening. Visible to no one else: positions, balances, the rest of the
books. Open interest is public; terms are bilateral; books are private.

## 9. Security considerations

- **Double-pledge**: infeasible by §1; this property is load-bearing
  and rests on post-state non-negativity in the transition target —
  any profile relaxing that bound voids this specification.
- **Stale-package race**: closed by nonce binding (§3, predicate 1).
- **Oracle failure or ambiguity**: expiry + `refund` path; attestor
  acceptability is an underwriting predicate, not a system constant.
- **Wash contracts** (self-dealing pairs inflating history): visible
  as netting pairs to any analyst of the public facts; reputation
  systems built on §6 SHOULD weight by counterparty diversity. Out of
  scope here.
- **Encumbrance griefing**: a party can strand only its *own* funds.
- **Settlement replay**: nullifiers (§5.3).
- **Escrow contract risk**: minimized by holding only the prefunded
  fraction and no logic beyond §4.
- **Scenario-set integrity** (§7): solvency holds per declared
  outcome column; undeclared outcomes, mis-partitioned conditions, or
  silently combined correlated conditions void the state-wise
  guarantee. The outcome partition is part of what both parties sign.

## 10. Conformance

An implementation conforms if it: produces and verifies the §2 objects
under 2/FACT; discharges every §3 predicate before activating a
margined contract; enforces §5.3 one-shot settlement; and renders §6
residuals to its underwriting policy. Reference deployment (informative,
see Register R1): a two-agent implementation with a sports-market
attestor and a minimal escrow on an EVM testnet.
