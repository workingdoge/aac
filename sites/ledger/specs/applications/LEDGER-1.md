# LEDGER/1 -- Committed Ledger State and Statement Interface

- Name: LEDGER/1 . Status: Raw . **Application surface (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 6/NAME, 7/DATA.

LEDGER/1 defines the user-facing object that application targets make
statements about: a committed private ledger state over an accounting context.
It gives AAC a vertex object. BCC/1, VNET/1, EVENT-COMPLETE/1, and
FUNDRAISE-CLEARING/1 are edge or policy surfaces that may bind to this object.

LEDGER/1 is not a new enshrined registry target, not a new circuit, not a
contract, and not a second balance semantics. It is an application-surface
vocabulary for interpreting committed state roots and for making public
statements over private books.

## 1. Non-redesign boundary

The base registry already stores row commitments and accepts updates through
TRANSITION/1 (3/PROOF section 4.1, 4/REG section 2). LEDGER/1 does not change
that update rule.

```
4/REG row            shared checkpoint: roots, context, fact fold, nonce
TRANSITION/1         enshrined proof: private journal updates committed state
LEDGER/1             application surface: what that committed state means
statement receipt    application proof/claim over a ledger state
```

The registry MAY store only the row defined by 4/REG. A deployment, wallet,
market, lender, clearing venue, or demo MAY interpret that row through LEDGER/1
when it wants to show or verify statements such as a balance sheet, round
capacity, cap table, receipt-holder set, or solvency condition.

## 2. Accounting context

A ledger is always indexed by an accounting context:

```text
LedgerContext := {
  ledger_id:              scalar_or_name
  controller:             name_or_namehash
  entity:                 name_or_namehash
  period_or_epoch:        scalar
  basis_order:            ordered basis type ids
  chart_commitment:       scalar
  policy_commitment:      scalar
  disclosure_scope:       scalar
  transition_profile:     target/profile id
  data_policy_ref:        evidence availability policy ref
}
```

The context fixes the local fibre in which 1/PACI terms are interpreted. The
basis names amount dimensions. The chart names account coordinates and
polarity. Policy and disclosure scope determine which statements a verifier may
ask for without changing the ledger's meaning.

The `context_commitment` carried in TRANSITION/1 public input slot 5 is the
commitment to the trusted deployment context that includes or resolves a
`LedgerContext`. A verifier MUST resolve it from trusted context, never from the
prover alone.

## 3. Ledger state

A ledger state is a private chart-indexed family of 1/PACI terms over one
`LedgerContext`.

```text
PrivateLedgerState<C> := {
  accounts: [
    {
      account_id
      polarity
      debit_vector
      credit_vector
    }
  ]
  journal_chain_ref
  opening_material
}
```

The public state header is:

```text
LedgerStateHeader := {
  ledger_id
  context_commitment
  account_root
  nullifier_root
  fact_fold
  fact_count
  nonce
  transition_version
}
```

`LedgerStateHeader` is the application reading of a 4/REG row. It does not add
state to the registry. A conforming LEDGER/1 verifier MUST treat the row's
`account_root`, `nullifier_root`, `fact_fold`, `fact_count`, and `nonce` as the
trusted checkpoint when the row is present.

## 4. Statements

A statement is a deterministic projection from a ledger state to a public claim.
A statement is not a second ledger.

```text
StatementRequest := {
  statement_type
  ledger_id
  context_commitment
  state_ref
  projection_policy
  selected_accounts
  selected_basis
  selected_period
  public_parameters
}
```

```text
StatementReceipt := {
  statement_type
  ledger_id
  context_commitment
  source_state_header
  statement_commitment
  public_claim
  proof_ref
  verifier_ref
  projection_policy
}
```

The statement receipt's job is to bind a public claim to one committed ledger
state under one projection policy. It does not mutate the ledger by itself.

Examples of statement types:

| statement type | public claim | private witness stays hidden |
|----------------|--------------|------------------------------|
| `balance_sheet` | selected assets, liabilities, equity satisfy the declared equation | account rows and journal chain |
| `round_capacity` | a raise has at least a public remaining capacity | issuer books, cap table rows, allocations |
| `receipt_issuance` | a receipt-token mint matches an accepted private transition | detailed subscription journals |
| `solvency_bound` | selected liabilities are covered under declared basis/policy | full account distribution |

## 5. Projection law

For a declared projection `P` from ledger context `C` to statement context `D`,
posting and projection MUST commute whenever both sides are claimed:

```text
P(post_C(ledger, journal)) = post_D(P(ledger), P(journal))
```

If a statement does not expose a posted statement journal, the weaker required
law is:

```text
statement_P(post_C(ledger, journal)) =
statement_P(next_ledger)
```

where `next_ledger` is the state committed by the accepted TRANSITION/1 public
inputs. Implementations MUST NOT present a public statement as a ledger fact
unless the statement binds to the source state header and projection policy that
make this law meaningful.

## 6. Transition binding

An application proof that claims a ledger state changed MUST bind to
TRANSITION/1 or to a verifier context that has already accepted the equivalent
transition.

For a direct TRANSITION/1 binding, the statement or application verifier checks:

```text
previous LedgerStateHeader.account_root == TRANSITION public input 0
next     LedgerStateHeader.account_root == TRANSITION public input 1
previous LedgerStateHeader.nullifier_root == TRANSITION public input 2
next     LedgerStateHeader.nullifier_root == TRANSITION public input 3
journal_commitment                         == TRANSITION public input 4
context_commitment                         == TRANSITION public input 5
```

The verifier also checks the target identity, proof, and trusted context under
3/PROOF section 5. A statement over a transition MUST NOT silently trust a
prover-supplied `journal_commitment`, `context_commitment`, or root.

## 7. Admissibility and descent boundary

LEDGER/1 distinguishes three layers:

```text
source evidence
-> admissibility/descent gate
-> constrained journal
-> TRANSITION/1 over LedgerStateHeader
-> statement projection
```

TRANSITION/1 proves balanced posting after the journal is supplied. The
admissibility/descent gate decides whether source evidence is allowed to emit
that journal. The statement projection decides what public claim follows from
the accepted state.

When a LEDGER/1 implementation claims a Premath-style admissibility or
statement-projection gate, it SHOULD use the following rejection vocabulary:

| class | AAC interpretation |
|-------|--------------------|
| `stability_failure` | statement meaning changes across entity, period, policy, basis, or chart context |
| `locality_failure` | ledger cannot restrict to the requested account, period, basis, or disclosure slice |
| `descent_failure` | local evidence or local ledger pieces do not glue into the claimed journal or statement |
| `glue_non_contractible` | the same evidence admits multiple incompatible journals or statements |

This vocabulary is a boundary contract. It does not require every LEDGER/1
deployment to implement a full Premath verifier.

## 8. Fundraise interpretation

For a private fundraising demo, LEDGER/1 gives the user-visible objects:

```text
issuer ledger pre-state
round capacity statement
investor fill
private settlement transition
issuer ledger post-state
receipt issuance statement
```

The user does not operate VNET/1 directly. VNET/1 may prove that selected
posted journals clear as amount vectors; BCC/1 may prove investor and issuer
agreement; FUNDRAISE-CLEARING/1 may bind payment, cap, private issuer journals,
and token issuance. LEDGER/1 names the ledger states and statement receipts
that those proofs are about.

## 9. Privacy posture

Public verifiers learn statement receipts, roots, commitments, and public
claims. They do not learn the private ledger rows unless a disclosure policy
opens them. A conforming UI MUST distinguish:

- private witness/operator view;
- public statement receipt;
- registry row checkpoint;
- settlement or token action authorized by policy.

Showing a private witness table as though it were verifier input is misleading.
Showing a statement receipt without its source state header is unverifiable.

## 10. Security considerations

- **Statement/ledger conflation.** A balance sheet, cap table view, or receipt
  list is a projection of ledger state, not a separate ledger. Treating it as
  independent state can hide projection failure.
- **Context drift.** Basis order, chart, period, policy, or disclosure scope
  changes can change statement meaning. Verifiers MUST bind statements to a
  context commitment.
- **Unchecked transition refs.** A statement over a transition is meaningless
  unless the verifier checks roots and `journal_commitment` against trusted
  TRANSITION/1 context.
- **Ambiguous evidence.** If source evidence admits two incompatible journals or
  statements, the gate MUST reject rather than choose one by convention.
