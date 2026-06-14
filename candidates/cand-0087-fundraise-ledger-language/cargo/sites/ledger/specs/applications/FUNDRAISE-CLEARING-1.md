# FUNDRAISE-CLEARING/1 -- Private Balance-Sheet Fundraising Settlement

- Name: FUNDRAISE-CLEARING/1 . Status: Raw . **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET, LEDGER/1, BCC/1, VNET/1.

This specification defines a non-enshrined target for a paid fundraising
round. It is the fundraise-specific statement surface over LEDGER/1: an issuer
starts from a committed private ledger state, proves a round-capacity statement,
admits a selected subscription batch, posts the private settlement transition,
and emits a receipt-issuance statement that a policy verifier can use to
authorize restricted token issuance. It is an accounting and settlement target.
It does not assert legal equity, regulatory compliance, or transfer permission
by itself.

The target exists because a fundraiser has two facts that should be tied
together without publishing the issuer's books:

1. the issuer's private ledger has enough declared round capacity for the
   selected subscription batch;
2. a public or externally attested payment settlement occurred; and
3. the issuer privately recognized that settlement in balanced books and in the
   capitalization ledger that determines issued units.

## 1. Non-redesign boundary

FUNDRAISE-CLEARING/1 composes with the enshrined targets. It does not alter
TRANSITION/1, NULLIFY/1, NET/1, or VNET/1, and it does not make any application
target a registry precondition.

```
TRANSITION/1          posts private issuer/cap-table journals
NULLIFY/1             prevents replay of subscription or issuance rights
NET/1                 closes channel facts when a deployment emits them
LEDGER/1              gives the issuer state and statement vocabulary
BCC/1                 records investor/issuer co-signed agreement certificates
VNET/1                proves selected posted journals net as amount vectors
FUNDRAISE-CLEARING/1  binds ledger statements to paid subscriptions and token mint
```

A round contract, clearing venue, lender, market, or admissibility layer MAY
require FUNDRAISE-CLEARING/1 before it mints or releases a restricted token.
The base registry MUST NOT.

## 2. Objects

### 2.0 Ledger fibre

A FUNDRAISE-CLEARING/1 instance is fibre-local over one or more LEDGER/1
contexts. At minimum it fixes:

```text
FundraiseLedgerSurface := {
  issuer_ledger_context:       LedgerContext
  cap_table_context:           LedgerContext
  round_capacity_statement:    StatementRequest(statement_type = round_capacity)
  balance_sheet_statement:     StatementRequest(statement_type = balance_sheet)
  receipt_issuance_statement:  StatementRequest(statement_type = receipt_issuance)
}
```

The issuer ledger pre-state is the source for the `round_capacity` statement.
The accepted private settlement transition is the vertical map between issuer
ledger states. The issuer ledger post-state is the source for the
`balance_sheet` and `receipt_issuance` statements. VNET/1 and BCC/1 support
that transition, but they are not the object the user operates: the user
operates a ledger state and asks for lawful statements over it.

The `context_commitment` in the public ABI resolves the round policy, the
ledger contexts, disclosure scopes, projection policies, verifier profiles, and
deployment adapters. A verifier MUST resolve those contexts from trusted policy
or registry state, never from prover-supplied text.

### 2.1 Round policy

A round policy is fixed before subscriptions are accepted:

```text
RoundPolicy := {
  round_id:                 scalar
  issuer_name:              name_or_namehash
  settlement_asset_type_id: basis type id      # e.g. atomic USDC units
  issued_unit_type_id:      basis type id      # e.g. class-A receipt unit
  price_numerator:          uint               # settlement units
  price_denominator:        uint               # issued units
  max_settlement_amount:    uint
  max_issued_units:         uint
  token_contract:           address_or_name
  transfer_policy_hash:     scalar
  admissibility_policy_hash: scalar
  settlement_adapter_hash:  scalar
  settlement_chain:         chain_or_domain id
  vault_or_contract:        custody/bridge contract or account
}
```

The policy hash is carried through `context_commitment`. A verifier MUST
resolve the policy from trusted context, never from the prover.

### 2.2 Subscription atom

A subscription atom is the clearing target's view of one approved investment:

```text
SubscriptionAtom := {
  subscription_id:       scalar
  investor_id:           scalar_or_address
  settlement_ref:        external settlement reference
  settlement_amount:     uint
  issued_units:          uint
  admissibility_ref:     scalar
  subscription_nullifier: scalar
}
```

`settlement_ref` is deployment-specific: it may name an on-chain payment, a
cross-chain settlement report, a workflow report, or another admissible
payment certificate. The proof does not make that reference true; the verifier
checks it against the round's settlement adapter.

### 2.3 BCC agreement

Each subscription MUST name a BCC/1 agreement certificate between the investor
and issuer. The BCC certificate is the agreement surface: it binds the parties,
the subscription event, the typed commitments, authenticated ECDH material, and
the finality/nullifier reference. It is not the private-state settlement proof.

For subscription `s`, the BCC event context includes at minimum:

```text
BccFundraiseContext := {
  round_id
  issuer_name
  investor_id
  subscription_id
  settlement_ref
  settlement_amount
  issued_units
  token_contract
}
```

The BCC bridge context includes:

```text
BccBridgeContext := {
  asset
  settlement_chain
  vault_or_contract
  deposit_ref
}
```

The FUNDRAISE-CLEARING/1 verifier checks that these contexts match the round
policy and subscription atom before it treats the BCC as admitted.

### 2.4 Bridge settlement

A bridge settlement report is the verifier's view of public custody:

```text
BridgeSettlement := {
  settlement_chain
  vault_or_contract
  asset_type_id
  accepted: [
    {
      subscription_id
      investor_id
      settlement_ref
      deposit_ref
      amount
    }
  ]
}
```

The report may be produced by a contract indexer, settlement adapter, CRE
workflow, or another trusted deployment-specific source. The proof does not
make the deposit true; the verifier checks the report against the configured
bridge/custody surface.

### 2.5 Issuer journal

The issuer recognizes each accepted subscription as a balanced private journal.
The canonical minimum journal has:

```text
Dr Cash or settlement receivable        settlement_amount
Cr Share capital / paid-in capital      settlement_amount
```

and a capitalization movement:

```text
Dr Subscription allocation right        issued_units
Cr Issued restricted units              issued_units
```

Profiles MAY split the credit across share capital, additional paid-in
capital, SAFE receipts, or another declared account set. The target requires
only that the policy fixes the account vocabulary and that every value-bearing
movement is represented as non-negative debit/credit coordinates in P^n.

## 3. The statement

Given a canonical ordered set of subscription atoms, FUNDRAISE-CLEARING/1
proves:

1. **Ledger context binding.** `prev_balance_sheet_root`,
   `next_balance_sheet_root`, `prev_cap_table_root`, `next_cap_table_root`,
   `transition_set_commitment`, and `context_commitment` are interpreted as
   LEDGER/1 state headers and statement contexts. The proof MUST bind the
   issuer ledger pre-state, issuer ledger post-state, cap-table pre-state,
   cap-table post-state, and projection policies used by the verifier.
2. **Round capacity statement.** Before accepting the selected batch, the
   issuer pre-state admits a `round_capacity` statement showing that the
   selected issued units and settlement amount fit inside the round policy.
   This is the public claim a user sees before transfer; it is not a reveal of
   the issuer's full balance sheet or cap table.
3. **Settlement binding.** The subscription set commitment binds every
   `(subscription_id, investor_id, settlement_ref, settlement_amount,
   issued_units, admissibility_ref, subscription_nullifier)` in canonical order.
4. **Payment/admissibility context.** Every subscription atom is in the
   settlement/admissibility report accepted by the verifier's trusted context.
   The proof binds the report commitments; the verifier checks the reports.
5. **BCC agreement binding.** Every subscription atom has a BCC/1 agreement
   certificate whose signed event context matches the round, issuer, investor,
   subscription id, settlement reference, amount, issued units, token contract,
   and bridge context. The verifier checks BCC signatures, cancellation
   opening, authenticated ECDH transcript binding, and BCC finality replay
   context before using the certificate.
6. **Bridge settlement binding.** Every subscription atom appears in the
   bridge settlement report for the policy's `settlement_chain`,
   `vault_or_contract`, and `settlement_asset_type_id`, with a matching
   deposit reference and amount.
7. **Issue-price arithmetic.** For every atom,
   `settlement_amount * price_denominator = issued_units * price_numerator`
   unless the round policy explicitly admits a rounding rule. Any rounding rule
   MUST be deterministic, monotone, and included in `context_commitment`.
8. **Round caps.** The accumulated settlement amount and issued units do not
   exceed `max_settlement_amount` or `max_issued_units`.
9. **Private settlement transition.** The private witness contains issuer journals
   that recognize the subscription amounts and issued units under the round
   policy's account vocabulary. Those journals connect the claimed old and new
   private roots through TRANSITION/1-compatible state arithmetic and LEDGER/1
   transition binding.
10. **Cap-table root update.** The private witness updates the cap-table root
   from `prev_cap_table_root` to `next_cap_table_root` by inserting or
   increasing the investors' allocations exactly by the issued units in the
   subscription set.
11. **Balance-sheet statement.** The issuer post-state admits the declared
   `balance_sheet` statement after applying the selected batch. The statement
   binds the previous root, next root, selected batch totals, projection policy,
   and verifier profile; it does not audit the truth of an unanchored previous
   root.
12. **VNET amount closure.** The posted fundraising journals are linked to a
   VNET/1 instance whose atoms reference the exact TRANSITION/1
   `journal_commitment` values for the issuer and cap-table movements. The
   VNET/1 proof MUST establish aggregate zero-opening; inspecting a Pedersen
   aggregate point is not sufficient.
13. **Nullifier discipline.** Each `subscription_nullifier` is nonzero and is
   consumed at most once. The verifier MUST reject a nullifier already accepted
   for the same round or policy context. BCC finality tags are also checked
   against the deployment replay surface before acceptance.
14. **Receipt issuance statement.** The public `mint_recipient_set_commitment`,
   `issued_unit_total`, `token_contract`, `round_id`,
   `bcc_set_commitment`, and `bridge_settlement_commitment` are exactly the
   values that a receipt-issuance statement and minting policy will use. A
   verifier MUST NOT authorize token issuance from a proof that is not bound to
   the token contract, round policy, BCC agreement set, bridge settlement
   context, issuer post-state, and receipt-issuance projection policy.

The proof binds accounting consistency. It does not prove the external payment
settlement or investor admissibility unless those checks are separately supplied
as trusted context.

## 4. Public ABI (order normative)

| # | name | notes |
|--:|------|-------|
| 0 | `round_id` | round policy identifier |
| 1 | `issuer_name` | issuer row/name context |
| 2 | `prev_balance_sheet_root` | LEDGER/1 issuer pre-state account root before recognition |
| 3 | `next_balance_sheet_root` | LEDGER/1 issuer post-state account root after recognition |
| 4 | `prev_cap_table_root` | LEDGER/1 cap-table pre-state before issuance |
| 5 | `next_cap_table_root` | LEDGER/1 cap-table post-state after issuance |
| 6 | `subscription_set_commitment` | order-binding fold over subscription atoms |
| 7 | `transition_set_commitment` | order-binding fold over linked TRANSITION refs and journal commitments |
| 8 | `vnet_public_commitment` | commitment to the accepted VNET/1 public input vector |
| 9 | `bcc_set_commitment` | order-binding fold over accepted BCC/1 agreement certificate summaries |
| 10 | `bridge_settlement_commitment` | commitment to the bridge/custody settlement report |
| 11 | `mint_recipient_set_commitment` | order-binding fold over public or committed mint recipients |
| 12 | `settlement_amount_total` | total accepted settlement asset amount |
| 13 | `issued_unit_total` | total restricted units to mint or release |
| 14 | `token_contract` | policy-bound token contract/name |
| 15 | `context_commitment` | `unconstrained`; binds round policy, LEDGER contexts, statement policies, adapters, bridge context, profile ids |

Inputs marked `unconstrained` carry meaning only through the verifier's context
checks under 3/PROOF section 5.

## 5. Verifier contract

A conforming FUNDRAISE-CLEARING/1 verifier, in order:

1. Resolves the target instance from deployment policy, never from the prover.
2. Verifies the proof against the pinned instance.
3. Resolves `round_id`, `issuer_name`, `token_contract`, and
   `context_commitment` against the round policy and LEDGER/1 contexts.
4. Checks that the issuer pre-state admits the declared `round_capacity`
   statement for the selected batch.
5. Checks the settlement adapter report for every `settlement_ref` included in
   `subscription_set_commitment`.
6. Checks the admissibility adapter report for every `admissibility_ref`.
7. Verifies every BCC/1 agreement certificate named by `bcc_set_commitment`,
   including signed transcript, cancellation opening, authenticated ECDH
   binding, and BCC finality/replay context.
8. Checks the bridge settlement report named by
   `bridge_settlement_commitment` against the policy's settlement chain,
   custody contract/account, asset type, deposit references, and amounts.
9. Resolves the referenced TRANSITION/1 updates and checks the
   `transition_set_commitment` against their accepted public inputs, including
   LEDGER/1 previous/next roots, `journal_commitment`, and
   `context_commitment`.
10. Verifies that the issuer post-state admits the declared `balance_sheet`
   statement and that the receipt mint inputs satisfy the declared
   `receipt_issuance` statement.
11. Verifies or resolves the VNET/1 certificate named by
   `vnet_public_commitment`, including VNET's transition linkage and
   zero-opening requirements.
12. Checks every subscription nullifier against the round's accepted-nullifier
   set, then records the new nullifiers atomically with acceptance.
13. Authorizes token mint/release only for `issued_unit_total`,
   `mint_recipient_set_commitment`, `round_id`, `token_contract`,
   `bcc_set_commitment`, and `bridge_settlement_commitment` from this proof.

The proof alone conveys no minting authority. Minting authority is the result
of proof verification plus all context checks above.

### 5.1 Demo settlement adapter

A deployment MAY place a thin settlement adapter after the verifier. The adapter
MUST NOT treat a raw prover packet as mint authority. It consumes a verifier or
orchestrator decision bound to the FUNDRAISE-CLEARING/1 public outputs.

The first Solidity adapter profile accepts an authorizer signature over an EVM
settlement digest containing:

```text
contract address
chain id
round_id hash
token contract
runtime authorization digest
runtime mint-recipient-set commitment
issued_unit_total
opened recipient list hash
```

The contract checks round and token equality, rejects empty or zero-recipient
sets, checks that opened recipient amounts sum to `issued_unit_total`, verifies
the authorizer signature, records the settlement digest to prevent replay, and
mints the restricted receipt token. The contract does not verify Noir/ProveKit
proofs; that remains the authorizer/orchestrator's obligation in this demo
profile.

## 6. Rejection requirements

A conforming instance MUST reject:

- a subscription atom not included in the committed subscription set;
- a ledger context, statement projection policy, or disclosure scope that is
  not bound by `context_commitment`;
- a round-capacity statement that is missing, stale, or bound to a different
  issuer pre-state;
- a payment or admissibility report that is not bound by `context_commitment`;
- issue-price arithmetic that does not match the round policy;
- any cap overflow or carrier-wraparound possibility;
- a token contract or round id that differs from the policy context;
- a missing BCC/1 agreement certificate for any subscription;
- a BCC/1 certificate with invalid signature, cancellation opening,
  authenticated ECDH binding, replayed finality tag, or context that differs
  from the subscription or round policy;
- a bridge settlement report whose chain, custody contract/account, asset,
  deposit reference, investor, or amount differs from the policy/subscription;
- a repeated or zero subscription nullifier;
- a cap-table update whose issued units differ from the subscription set;
- a balance-sheet statement that is not bound to the issuer post-state and
  selected batch;
- a receipt-issuance statement that is not bound to the issuer post-state,
  token contract, mint recipient set, and issued-unit total;
- a VNET certificate that is missing, references a different transition set,
  omits a fundraising journal, or lacks aggregate zero-opening;
- a Pedersen/VNET proof over points that are not linked to posted
  TRANSITION/1 `journal_commitment` values;
- a proof that discloses public mint totals but leaves the mint recipient set
  unbound.

## 7. Deployment notes (non-normative)

A hackathon deployment can instantiate the settlement adapter with a cross-chain
stablecoin routing system and instantiate the admissibility adapter with an
orchestration workflow that checks KYC, accreditation, or an issuer-maintained
allowlist. Those adapters are outside this target. The target sees only their
committed reports and the policy context that says the verifier trusts them.

For a public demo, "restricted token", "investment receipt", or "SAFE receipt"
is the precise language. "Equity" is a legal status created by off-chain
documents and law, not by this proof target.

## 8. Security considerations

FUNDRAISE-CLEARING/1 proves internal consistency of a paid subscription batch
as statements over committed ledger state. It does not prove the issuer's
starting balance sheet is true. A deployment that needs truth must anchor
`prev_balance_sheet_root` through an auditor, bank/accounting-data adapter,
prior accepted registry state, or another trusted source.

The public chain will generally see token issuance, recipient addresses if the
token mints directly to them, and settlement amounts needed by the payment
rail. The target's privacy is the issuer's internal balance sheet, account
vocabulary, allocation derivation, and any committed recipient set not otherwise
opened by the token contract.

## 9. Implementation status (non-normative)

The transparent demo packet checker
[`fundraise_demo.py`](reference/fundraise_demo.py), with fixtures at
[`FUNDRAISE-DEMO-1.json`](vectors/FUNDRAISE-DEMO-1.json), exercises one
private-ledger fundraising transcript. The JavaScript runtime uses the
dependency-free `vnet-runtime` reference verifier for `VNET-BN254-G1/1` point
encodings, generator derivation, transition-link certificates, and aggregate
zero-opening. The reference surfaces bind a round policy, subscriptions,
settlement/admissibility reports, VNET transition-link verification, bridge
settlement binding, BCC agreement certificates, and mint authorization, then
reject BCC, bridge, price, settlement, token, and VNET failures.

The Solidity demo adapter
[`registry/src/FundraiseSettlement.sol`](../../../../registry/src/FundraiseSettlement.sol)
consumes the runtime's EVM-shaped authorized-mint receipt, verifies an
authorizer signature, prevents replay, and mints a minimal restricted receipt
token. It is not a recursive verifier and does not verify the private-state
proof on-chain.

The JavaScript `fundraise-authorizer` package is the current off-chain
authorizer seam. It verifies a fundraise packet through `fundraise-runtime`,
binds the EVM mint authorization to deployment policy fields, and emits a
deterministic settlement signing request/receipt for the contract authorizer
role. It does not sign Ethereum messages, verify ProveKit proofs, run a CRE
workflow, or compute the Solidity `settlementDigest`; those remain deployment
obligations above the request surface.

The JavaScript `fundraise-workflow` package is the current orchestration core
above that seam. It takes a normalized verifier receipt, rejects stale or
policy-inadmissible proof receipts, calls the authorizer, and returns the
deterministic settlement action for `FundraiseMintSettlement.settle`. It does
not import the CRE SDK, verify ProveKit proofs, sign transactions, submit
transactions, or manage keys. A real CRE workflow or ProveKit verifier service
is expected to produce the verifier receipt and consume the workflow output.

The JavaScript `fundraise-provekit-adapter` package is the current normalized
verifier-receipt producer for ProveKit paths. It does not run ProveKit or verify
proofs itself; instead, it takes an already-accepted ProveKit WHIR/Groth16
verification result and binds proof metadata, public inputs, verifier-key digest,
timings, and packet commitment into the receipt consumed by `fundraise-workflow`.
This is the intended handoff from a native CLI, browser-WASM wrapper, verifier
service, or CRE workflow into the settlement workflow.

The next implementation slices should replace the adapter's caller with an
actual CRE workflow simulation or ProveKit verifier service, then deploy the
adapter to a testnet token contract. Non-mock BCC signature and cancellation
schemes are adapter surfaces: they fail closed unless a deployment verifier
accepts them.
