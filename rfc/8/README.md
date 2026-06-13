# 8/SESS — Bilateral Payment Sessions

- Name: 8/SESS · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 4/REG.

Two parties transact over an ordinary request/response transport (HTTP
in the registered annexes) with no intermediary: micro-payments
accumulate privately in both ledgers, settle publicly as nets, and neither
party can cheat without producing a residual or a nullifier collision.
Transport annexes map MPP and x402 onto this core; the core consumes and
produces 2/FACT objects only.

## 1. Roles and objects

**Payer** and **payee**; no third role exists. Objects:
- `Challenge { scope, session, price, asset, expiry }` — issued by payee;
  `scope` MUST bind payee identity and resource class; `session` MUST be
  unique.
- `MicroAuth` — payer-signed transfer authorization for one Challenge,
  with `validBefore ≤ now + T_micro` (minutes-scale) and a unique nonce.
- `NetAuth` — payer-signed authorization for the net of a set of
  MicroAuths, superseding them, with longer validity.
- `Receipt { payment_id, challenge, auth_digest, deliverable_digest }` —
  payee-signed proof of delivery.

## 2. Fact mapping

Per accepted payment: payer posts a push, payee a pull, on channel
`(asset)` with `message ⊇ { payment_id, scope }`; both reference the
Receipt digest. The right to settle a given authorization is a 1/PACI §5
right: nullifier preimage = the authorization's factId. A NetAuth's
acceptance consumes (nullifies) the rights of every MicroAuth it
supersedes.

## 3. Session state machine

```
OPEN ──MicroAuth*──► ACCUMULATING ──checkpoint──► NETTING ──settle──► SETTLED
                          │ payer silent / dispute                ▲
                          └────────── payee settles micros ───────┘
```
- ACCUMULATING: payee delivers against each verified MicroAuth and MUST
  issue a Receipt per delivery.
- Checkpoint (either party MAY trigger; payee SHOULD before ΣT_micro
  expiry pressure): payer signs NetAuth for the accumulated net; both post
  the superseding facts; micro rights are nullified.
- Fallback: at any moment, payee MAY settle outstanding MicroAuths
  on-chain before their expiry. This loses payment-graph privacy for the
  session; it never loses money.

## 4. Safety (informal theorems, conformance-tested)

- **Payee safety**: at every state, payee holds settleable authorizations
  ≥ value delivered since last settlement (deliver only after verifying;
  settle before expiry on payer silence).
- **Payer safety**: exposure ≤ Σ outstanding authorization caps, each
  expiring within T_micro; NetAuth issuance never increases exposure
  (supersession nullifies as it grants).
- **No double-settlement**: settling both a MicroAuth and the NetAuth that
  superseded it is a nullifier collision; conforming verifiers and the
  registry reject the second.

## 5. Privacy

Individual payments never reach the chain in the optimistic path; only
session nets do. The anonymity afforded is **temporal aggregation within
the pair**, and deployments MUST NOT claim payer–payee unlinkability
beyond it (that property requires a netting set larger than two; see
reserved 10/ADMIT for rings).

## 6. Transport annexes

- **mpp/1**: Challenge ⇄ `WWW-Authenticate: Payment`; MicroAuth/NetAuth ⇄
  payment Credential; Receipt ⇄ `Payment-Receipt`. MPP receipts are
  adapter inputs (2/FACT §5); their delivery semantics map to `Receipt`.
- **x402/1**: Challenge ⇄ 402 payment-requirements; authorizations ⇄
  EIP-3009 `transferWithAuthorization` payloads (nonce = the
  authorization nonce; expiry = `validBefore`); Receipt is supplied by
  this specification (x402 lacks one) and MUST be issued as in §3.

## 7. Security considerations

Scope-unbound challenges enable relay of authorizations across payees —
`scope` binding in §1 is mandatory; clock skew bounds T_micro from below;
Receipt withholding by the payee is visible non-conformance the payer
answers by ceasing MicroAuth issuance (exposure stays bounded by §4).
