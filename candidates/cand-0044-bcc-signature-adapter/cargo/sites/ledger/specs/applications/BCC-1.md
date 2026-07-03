# BCC/1 -- Bilateral Cancellation Certificate

- Name: BCC/1 . Status: Raw . **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, VNET/1.

BCC/1 defines a bilateral agreement certificate for one commercial edge: two
parties commit to opposite typed private records, publish an aggregate
cancellation opening, sign the same transcript, optionally authenticate
ephemeral ECDH keys for private edge material, and bind finality/nullifier
references for an external replay surface.

BCC/1 is not a settlement proof, bridge proof, or base-registry condition. A
settlement verifier MAY consume a BCC/1 certificate as an input, but state
membership, nullifier derivation, post-state creation, bridge custody, token
mint/burn/release, and deployment-specific predicates are discharged by the
private-state and settlement layers above BCC/1.

## 1. Role separation

BCC/1 separates five jobs:

1. **Typed Pedersen cancellation.** Each party's private local record is hidden
   behind a commitment over an agreed basis. The public certificate proves or
   checks that the two committed records aggregate to the zero value vector:
   `C_A + C_B = R * H`.
2. **Signatures.** Both parties sign the same transcript, binding them to the
   event, basis/profile, commitments, cancellation opening, state references,
   finality material, and authenticated ECDH public keys.
3. **Authenticated ECDH.** Optional ephemeral ECDH public keys derive pairwise
   private edge material for encryption, view-key salt, session identity, or
   private edge tags. ECDH is authenticated only because the ephemeral public
   keys are inside the co-signed transcript. There is no separate "DH
   signature" primitive.
4. **Finality references.** Replay prevention and global finality require a
   co-signed certificate plus an append-only log, nullifier set, settlement
   registry, or equivalent uniqueness surface. ECDH is not finality.
5. **Settlement consumption.** A bridge contract, registry, or policy verifier
   may accept BCC/1 only together with the required private-state proof,
   predicate proof, or external attestation for that deployment.

The concise rule is:

```text
Pedersen nets the books.
Signatures bind the parties.
Authenticated ECDH seals the private edge.
Consensus finalizes the state.
Contracts bridge assets in and out.
```

## 1.1 Noir and proof-stack boundary

BCC/1 signature verification is an application/settlement verifier obligation
unless a deployment explicitly chooses an in-circuit signature profile. The
kernel Noir targets do not need to verify wallet signatures to compose with
BCC/1.

Noir, ProveKit, or another settlement proof composes with BCC/1 by binding the
certificate's public artifacts:

```text
transcript_hash
finality/nullifier refs
transition_ref values
journal_commitment values
BCC set commitment
context commitment
```

A verifier MAY pass "the BCC signatures were accepted under policy P" as trusted
context to a proof, or MAY verify signatures inside a separate proof target. It
MUST NOT silently treat an unchecked BCC transcript as a signed agreement.

## 2. Public certificate and private witness

A BCC/1 public certificate contains commitments and references, not the private
debit/credit vectors:

```text
BccCertificate := {
  schema:                "aac.bcc.certificate.v1"
  event:                 typed bilateral event descriptor
  basis_type_ids:        ordered typed basis ids
  records:               [BccPublicRecord, BccPublicRecord]
  cancellation_opening:  aggregate zero-opening certificate
  authenticated_dh:      optional authenticated ephemeral ECDH public keys
  finality:              replay/nullifier/log context
  transcript_hash:       H(canonical transcript payload)
  signatures:            party signatures over transcript_hash
}

BccPublicRecord := {
  party_id:              party/name/address id
  role:                  e.g. buyer | seller | investor | issuer
  transition_ref:        accepted TRANSITION/1 row update reference, if posted
  journal_commitment:    exact TRANSITION/1 ABI slot 4 value, if posted
  basis_type_ids:        same ordered basis as the certificate
  record_commitment:     commitment to the party's private local record
}
```

The private witness is held by counterparties or a prover:

```text
BccPrivateWitness := {
  records: [
    {
      party_id
      role
      basis_type_ids
      debit              # private non-negative vector
      credit             # private non-negative vector
      record_blinding
    },
    ...
  ]
  aggregate_opening:     R
  encrypted_payloads:    optional invoice, terms, docs, view material
}
```

For a typed signed value vector `z = debit - credit`, the intended commitment
relation is:

```text
C_A = Commit_B(z_A, r_A)
C_B = Commit_B(z_B, r_B)
z_A + z_B = 0
C_A + C_B = R * H
R = r_A + r_B
```

The certificate's `basis_type_ids`, generator profile, schema version, and
domain separators MUST be signed in the transcript. A verifier MUST NOT net
untyped numbers or let one basis dimension settle another.

## 3. Authenticated ECDH

When `authenticated_dh` is present, it declares ephemeral public keys and KDF
metadata:

```text
AuthenticatedDh := {
  scheme:                 e.g. x25519-authenticated/1
  ephemeral_public_keys:  { party_id -> public_key }
  kdf:                    e.g. hkdf-sha256
  transcript_binding:     ephemeral keys are signed inside transcript_hash
  public_edge_tag:        optional deployment/public tag
}
```

The parties derive shared material out of band:

```text
s_AB = ECDH(a, E_B) = ECDH(b, E_A)
keys = KDF(s_AB, salt = transcript_hash, info = "aac/bcc/authenticated-ecdh/1")
```

The public verifier checks that the ECDH public keys named by the certificate
are included in the signed transcript. The verifier MUST NOT treat a private
ECDH-derived tag as public finality unless the deployment opens or proves the
derivation.

## 3.1 Signature adapter profile

A BCC/1 runtime MAY support multiple signature schemes. The first executable
runtime keeps `mock-signature/1` only as a fixture adapter. Any non-mock scheme
MUST be verified by a deployment-supplied signature verifier.

For wallet-style signatures, the canonical payload is the BCC typed-data
message:

```text
BccSignatureTypedData := {
  schema:       "aac.bcc.signature-typed-data.v1"
  kind:         "eip712-compatible"
  domain:       { name, version, chainId, verifyingContract, salt }
  primaryType:  "BccCertificateSignature"
  message: {
    certificateSchema
    transcriptHash
    partyId
    publicKey
    signatureScheme
    finalityTag
    nullifier
    logRef
  }
}
```

The typed-data message signs the `transcriptHash`, not a re-expanded copy of
the private commercial record. The transcript hash already binds the event,
typed commitments, authenticated ECDH public keys, finality refs, and state
refs. A conforming verifier MUST reject any non-mock signature whose scheme has
no configured verifier adapter.

## 4. Statement

Given a canonical BCC/1 certificate, a conforming public verifier checks:

1. **Two-party shape.** The certificate contains exactly two public records
   with distinct `party_id` values and common `basis_type_ids`.
2. **Private witness separation.** The public certificate does not carry
   private debit/credit vectors, private blindings, invoices, or decrypted
   commercial payloads.
3. **Commitment profile.** Every record commitment uses the declared typed
   commitment profile and basis. Production profiles MUST validate point
   encodings, subgroup membership, generator derivation, amount bounds, and
   domain separation according to their profile.
4. **Cancellation opening.** The aggregate commitment relation opens to the
   zero value vector: `C_A + C_B = R * H`. Merely producing a group point is not
   enough.
5. **Signed agreement.** Every required party signature verifies over the same
   `transcript_hash`. Non-mock schemes verify through the deployment's
   configured signature adapter and MUST fail closed when no adapter is
   available.
6. **Authenticated ECDH boundary.** If ECDH material is present, every
   ephemeral public key is bound into the signed transcript and belongs to a
   certificate party.
7. **Replay/finality reference.** The finality tag or nullifier is checked
   against the deployment's accepted set, append-only log, bridge, or registry
   before acceptance.

A conforming private-witness verifier additionally checks that the witnessed
private records open the public commitments and that their signed value vectors
sum to zero. This witness check is not the same thing as settlement.

## 5. Settlement and bridge boundary

BCC/1 says:

```text
these two parties agreed to opposite private typed records
```

It does not say:

```text
the pre-state was included in a registry root
the nullifier is fresh
the post-state was correctly formed
the bridge has custody of the asset
the token mint/release is authorized
the cap table, solvency, compliance, or collateral policy is satisfied
```

A settlement verifier that consumes BCC/1 MUST discharge those additional
obligations separately. A typical private asset bridge has three phases:

```text
deposit:
  lock or escrow a public asset in a contract
  create a private state commitment
  include the commitment in a registry root

private transfer:
  verify BCC/1 agreement certificate
  prove pre-state membership
  derive and consume a fresh nullifier
  create post-state commitments
  update the registry root

withdraw:
  prove ownership of a private state
  reveal recipient and withdrawal amount
  consume the nullifier
  release, mint, burn, or transfer the public asset
```

ProveKit, a native SNARK verifier, or a coSNARK may implement those settlement
proofs. CRE or another orchestration layer may collect signatures, query
external systems, run proof generation, and submit contract calls. None of
those layers makes BCC/1 itself a bridge contract or consensus rule.

## 6. Example

For a goods-for-cash event over basis `[goods, USD]`:

```text
buyer private record:   Dr goods 3 / Cr USD 10
seller private record:  Dr USD 10  / Cr goods 3
```

The public certificate carries:

```text
C_buyer
C_seller
R
transcript_hash
sig_buyer
sig_seller
authenticated ECDH public keys
finality/nullifier refs
```

The cancellation view checks:

```text
C_buyer + C_seller = R * H
```

The private records remain with the counterparties, an auditor, or a prover
unless a deployment explicitly requires disclosure.

## 7. Rejection requirements

A conforming BCC/1 verifier MUST reject:

- missing or duplicate party records;
- mixed basis order, mixed commitment profile, or ambiguous basis identity;
- public certificates that expose private debit/credit vectors or blindings;
- a record commitment that is malformed for the declared profile;
- a cancellation opening that does not prove `C_A + C_B = R * H`;
- a signature over a different transcript;
- a non-mock signature whose verifier adapter is missing or rejects the typed
  data payload;
- authenticated ECDH material whose ephemeral public keys are not in the signed
  transcript or do not belong to the certificate parties;
- a replayed finality tag or nullifier;
- a certificate that claims global finality from ECDH alone;
- a certificate that claims bridge settlement without the deployment's separate
  state, nullifier, custody, and policy checks.

## 8. Relation to VNET/1

BCC/1 and VNET/1 are related but not identical:

```text
BCC/1   one bilateral commercial edge cancels
VNET/1  a selected batch of posted journals clears per basis dimension
```

VNET/1 MAY consume BCC-linked atoms, and a BCC settlement workflow MAY require
a VNET/1 proof for batch clearing. The BCC/1 primitive remains the co-signed
bilateral cancellation certificate.

## 9. Implementation status (non-normative)

The executable implementation is the dependency-free JavaScript runtime
[`bcc-runtime`](../../../bcc-runtime/README.md), with demo vectors at
[`BCC-DEMO-1.json`](vectors/BCC-DEMO-1.json). It uses deterministic mock
record commitments, mock cancellation openings, mock signatures, and mock
authenticated ECDH tags so the fixture suite is reproducible without external
wallet, curve, or proving dependencies.

Those mock seams are not production cryptography. Production integration should
replace them with typed Pedersen commitments, aggregate zero-opening
verification, wallet/EIP-712/passkey signatures over the typed-data payload,
real authenticated ECDH handling, and separate settlement proofs or contracts
for registry admission and asset bridging. BCC/1 does not add a base-registry
condition.
