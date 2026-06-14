# FUNDRAISE-CLEARING/1 -- Private Balance-Sheet Fundraising Settlement

- Name: FUNDRAISE-CLEARING/1 . Status: Raw . **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET, BCC/1, VNET/1.

This specification defines a non-enshrined target for a paid fundraising
round: approved subscription settlements update an issuer's private balance
sheet and cap table, and a policy verifier uses the accepted proof to authorize
restricted token issuance. It is an accounting and settlement target. It does
not assert legal equity, regulatory compliance, or transfer permission by
itself.

The target exists because a fundraiser has two facts that should be tied
together without publishing the issuer's books:

1. a public or externally attested payment settlement occurred; and
2. the issuer privately recognized that settlement in balanced books and in the
   capitalization ledger that determines issued units.

## 1. Non-redesign boundary

FUNDRAISE-CLEARING/1 composes with the enshrined targets. It does not alter
TRANSITION/1, NULLIFY/1, NET/1, or VNET/1, and it does not make any application
target a registry precondition.

```
TRANSITION/1          posts private issuer/cap-table journals
NULLIFY/1             prevents replay of subscription or issuance rights
NET/1                 closes channel facts when a deployment emits them
BCC/1                 records investor/issuer co-signed agreement certificates
VNET/1                proves selected posted journals net as amount vectors
FUNDRAISE-CLEARING/1  binds paid subscriptions to private books and token mint
```

A round contract, clearing venue, lender, market, or admissibility layer MAY
require FUNDRAISE-CLEARING/1 before it mints or releases a restricted token.
The base registry MUST NOT.

## 2. Objects

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

1. **Settlement binding.** The subscription set commitment binds every
   `(subscription_id, investor_id, settlement_ref, settlement_amount,
   issued_units, admissibility_ref, subscription_nullifier)` in canonical order.
2. **Payment/admissibility context.** Every subscription atom is in the
   settlement/admissibility report accepted by the verifier's trusted context.
   The proof binds the report commitments; the verifier checks the reports.
3. **BCC agreement binding.** Every subscription atom has a BCC/1 agreement
   certificate whose signed event context matches the round, issuer, investor,
   subscription id, settlement reference, amount, issued units, token contract,
   and bridge context. The verifier checks BCC signatures, cancellation
   opening, authenticated ECDH transcript binding, and BCC finality replay
   context before using the certificate.
4. **Bridge settlement binding.** Every subscription atom appears in the
   bridge settlement report for the policy's `settlement_chain`,
   `vault_or_contract`, and `settlement_asset_type_id`, with a matching
   deposit reference and amount.
5. **Issue-price arithmetic.** For every atom,
   `settlement_amount * price_denominator = issued_units * price_numerator`
   unless the round policy explicitly admits a rounding rule. Any rounding rule
   MUST be deterministic, monotone, and included in `context_commitment`.
6. **Round caps.** The accumulated settlement amount and issued units do not
   exceed `max_settlement_amount` or `max_issued_units`.
7. **Private issuer accounting.** The private witness contains issuer journals
   that recognize the subscription amounts and issued units under the round
   policy's account vocabulary. Those journals connect the claimed old and new
   private roots through TRANSITION/1-compatible state arithmetic.
8. **Cap-table root update.** The private witness updates the cap-table root
   from `prev_cap_table_root` to `next_cap_table_root` by inserting or
   increasing the investors' allocations exactly by the issued units in the
   subscription set.
9. **VNET amount closure.** The posted fundraising journals are linked to a
   VNET/1 instance whose atoms reference the exact TRANSITION/1
   `journal_commitment` values for the issuer and cap-table movements. The
   VNET/1 proof MUST establish aggregate zero-opening; inspecting a Pedersen
   aggregate point is not sufficient.
10. **Nullifier discipline.** Each `subscription_nullifier` is nonzero and is
   consumed at most once. The verifier MUST reject a nullifier already accepted
   for the same round or policy context. BCC finality tags are also checked
   against the deployment replay surface before acceptance.
11. **Token issuance binding.** The public `mint_recipient_set_commitment`,
   `issued_unit_total`, `token_contract`, `round_id`,
   `bcc_set_commitment`, and `bridge_settlement_commitment` are exactly the
   values that a minting policy will use. A verifier MUST NOT authorize token
   issuance from a proof that is not bound to the token contract, round policy,
   BCC agreement set, and bridge settlement context.

The proof binds accounting consistency. It does not prove the external payment
settlement or investor admissibility unless those checks are separately supplied
as trusted context.

## 4. Public ABI (order normative)

| # | name | notes |
|--:|------|-------|
| 0 | `round_id` | round policy identifier |
| 1 | `issuer_name` | issuer row/name context |
| 2 | `prev_balance_sheet_root` | private issuer accounting root before recognition |
| 3 | `next_balance_sheet_root` | private issuer accounting root after recognition |
| 4 | `prev_cap_table_root` | private capitalization root before issuance |
| 5 | `next_cap_table_root` | private capitalization root after issuance |
| 6 | `subscription_set_commitment` | order-binding fold over subscription atoms |
| 7 | `transition_set_commitment` | order-binding fold over linked TRANSITION refs |
| 8 | `vnet_public_commitment` | commitment to the accepted VNET/1 public input vector |
| 9 | `bcc_set_commitment` | order-binding fold over accepted BCC/1 agreement certificate summaries |
| 10 | `bridge_settlement_commitment` | commitment to the bridge/custody settlement report |
| 11 | `mint_recipient_set_commitment` | order-binding fold over public or committed mint recipients |
| 12 | `settlement_amount_total` | total accepted settlement asset amount |
| 13 | `issued_unit_total` | total restricted units to mint or release |
| 14 | `token_contract` | policy-bound token contract/name |
| 15 | `context_commitment` | `unconstrained`; binds round policy, adapters, bridge context, profile ids |

Inputs marked `unconstrained` carry meaning only through the verifier's context
checks under 3/PROOF section 5.

## 5. Verifier contract

A conforming FUNDRAISE-CLEARING/1 verifier, in order:

1. Resolves the target instance from deployment policy, never from the prover.
2. Verifies the proof against the pinned instance.
3. Resolves `round_id`, `issuer_name`, `token_contract`, and
   `context_commitment` against the round policy.
4. Checks the settlement adapter report for every `settlement_ref` included in
   `subscription_set_commitment`.
5. Checks the admissibility adapter report for every `admissibility_ref`.
6. Verifies every BCC/1 agreement certificate named by `bcc_set_commitment`,
   including signed transcript, cancellation opening, authenticated ECDH
   binding, and BCC finality/replay context.
7. Checks the bridge settlement report named by
   `bridge_settlement_commitment` against the policy's settlement chain,
   custody contract/account, asset type, deposit references, and amounts.
8. Resolves the referenced TRANSITION/1 updates and checks the
   `transition_set_commitment` against their accepted public inputs.
9. Verifies or resolves the VNET/1 certificate named by
   `vnet_public_commitment`, including VNET's transition linkage and
   zero-opening requirements.
10. Checks every subscription nullifier against the round's accepted-nullifier
   set, then records the new nullifiers atomically with acceptance.
11. Authorizes token mint/release only for `issued_unit_total`,
   `mint_recipient_set_commitment`, `round_id`, `token_contract`,
   `bcc_set_commitment`, and `bridge_settlement_commitment` from this proof.

The proof alone conveys no minting authority. Minting authority is the result
of proof verification plus all context checks above.

## 6. Rejection requirements

A conforming instance MUST reject:

- a subscription atom not included in the committed subscription set;
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

FUNDRAISE-CLEARING/1 proves internal consistency of a paid subscription batch.
It does not prove the issuer's starting balance sheet is true. A deployment
that needs truth must anchor `prev_balance_sheet_root` through an auditor,
bank/accounting-data adapter, prior accepted registry state, or another trusted
source.

The public chain will generally see token issuance, recipient addresses if the
token mints directly to them, and settlement amounts needed by the payment
rail. The target's privacy is the issuer's internal balance sheet, account
vocabulary, allocation derivation, and any committed recipient set not otherwise
opened by the token contract.

## 9. Implementation status (non-normative)

The transparent demo packet checker
[`fundraise_demo.py`](reference/fundraise_demo.py), with fixtures at
[`FUNDRAISE-DEMO-1.json`](vectors/FUNDRAISE-DEMO-1.json), exercises one
private-balance-sheet fundraising transcript. The JavaScript runtime uses the
dependency-free `vnet-runtime` reference verifier for `VNET-BN254-G1/1` point
encodings, generator derivation, transition-link certificates, and aggregate
zero-opening. The reference surfaces bind a round policy, subscriptions,
settlement/admissibility reports, VNET transition-link verification, bridge
settlement binding, BCC agreement certificates, and mint authorization, then
reject BCC, bridge, price, settlement, token, and VNET failures.

No reference circuit, native verifier, verifier contract, token contract,
settlement adapter, CRE workflow, Circle integration, or ProveKit integration is
assigned by this candidate. The next implementation slices should choose the
production recursive/contract VNET proof verification strategy, then bind a demo
settlement/orchestration adapter to a testnet token contract. Non-mock BCC
signature and cancellation schemes are adapter surfaces: they fail closed unless
a deployment verifier accepts them.
