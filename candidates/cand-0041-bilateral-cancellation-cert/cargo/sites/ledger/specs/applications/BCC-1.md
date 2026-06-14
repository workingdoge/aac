# BCC/1 -- Bilateral Cancellation Certificate

- Name: BCC/1 . Status: Raw . **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, VNET/1.

BCC/1 defines a bilateral certificate for one commercial edge: two parties sign
opposite committed records, a VNET-style zero-sum check proves the records
cancel per basis dimension, optional Diffie-Hellman material seals the private
edge, and a finality/nullifier tag makes the certificate replay-detectable.

It is an application target. The base registry MUST NOT require BCC/1. A market,
workflow, settlement venue, or token policy MAY require a BCC/1 certificate
before admitting a transaction, releasing funds, or minting a receipt.

## 1. Role separation

BCC/1 separates four jobs:

1. **Pedersen/VNET netting.** Amount-vector commitments prove the two local
   records cancel without revealing the private quantities to outsiders.
2. **Signatures.** Both parties sign the same transcript, binding them to the
   event, commitments, transition refs, and finality material.
3. **Diffie-Hellman edge material.** Optional ephemeral keys derive a pairwise
   private value for encryption, blinding coordination, session identity, or a
   private edge tag. DH is not global finality.
4. **Finality surface.** Replay prevention and global finality require a
   co-signed certificate plus an append-only log, nullifier set, settlement
   registry, or equivalent uniqueness surface.

The concise rule is:

```text
Pedersen nets the books.
Signatures bind the parties.
Diffie-Hellman seals the edge.
Consensus finalizes the state.
```

## 2. Certificate object

```text
BccCertificate := {
  schema:             "aac.bcc.certificate.v1"
  event:              typed bilateral event descriptor
  basis_type_ids:     ordered P^n basis ids
  records:            [BccRecord, BccRecord]
  vnet_certificate:   VNET-style cancellation certificate
  dh_edge:            optional authenticated ephemeral public keys + edge tag
  finality:           replay/nullifier/log context
  transcript_hash:    H(canonical transcript payload)
  signatures:         party signatures over transcript_hash
}

BccRecord := {
  party_id:           party/name/address id
  role:               e.g. buyer | seller
  transition_ref:     accepted TRANSITION/1 row update reference
  journal_commitment: exact TRANSITION/1 ABI slot 4 value
  debit:              non-negative amount vector over basis_type_ids
  credit:             non-negative amount vector over basis_type_ids
  debit_commitment:   VNET commitment to debit vector
  credit_commitment:  VNET commitment to credit vector
}
```

## 3. Statement

Given a canonical BCC/1 certificate, a conforming verifier proves or checks:

1. **Two-party shape.** The certificate contains exactly two party records with
   distinct `party_id` values and common `basis_type_ids`.
2. **Transition linkage.** Every record references an accepted TRANSITION/1
   update, and the record's `journal_commitment` is the exact public input
   accepted for that transition.
3. **Commitment opening.** Each debit and credit commitment opens to bounded
   non-negative coordinates over the declared basis under the chosen VNET
   profile.
4. **Opposite orientation.** The aggregate debit vector equals the aggregate
   credit vector per basis dimension. No basis may settle another basis.
5. **Zero opening.** The VNET aggregate proves
   `sum(C_D) - sum(C_C) = R * H`; merely producing a group point is not enough.
6. **Signed agreement.** Every required party signature verifies over the same
   `transcript_hash`.
7. **DH boundary.** If `dh_edge` is present, its ephemeral keys and derived tags
   are included in the signed transcript. The verifier MUST NOT treat a private
   DH-derived tag as public finality unless the derivation is opened or proven.
8. **Replay/finality.** The finality tag or nullifier MUST be checked against
   the deployment's accepted set or append-only log before acceptance.

## 4. Example

For a goods-for-cash event over basis `[goods, USD]`:

```text
buyer:  Dr goods 3 / Cr USD 10
seller: Dr USD 10  / Cr goods 3
```

The VNET view checks:

```text
sum debits  = [3 goods, 10 USD]
sum credits = [3 goods, 10 USD]
```

The certificate is accepted only when both party signatures bind that same
transcript and the finality surface has not already accepted the tag.

## 5. Rejection requirements

A conforming BCC/1 verifier MUST reject:

- missing or duplicate party records;
- mixed basis order or mixed VNET profile;
- a record whose commitment does not open to the declared debit/credit vector;
- a VNET certificate that does not zero-open;
- a signature over a different transcript;
- a DH edge tag not bound into the signed transcript when DH material is
  declared;
- a replayed finality tag or nullifier;
- a certificate that claims global finality from DH alone.

## 6. Implementation status (non-normative)

The first executable implementation is the dependency-free JavaScript runtime
[`bcc-runtime`](../../../bcc-runtime/README.md), with demo vectors at
[`BCC-DEMO-1.json`](vectors/BCC-DEMO-1.json). It uses deterministic
mock-vector commitments, mock signatures, and mock DH edge tags so the fixture
suite is reproducible without external wallet or proving dependencies.

Those mock seams are not production cryptography. Production integration should
replace them with the VNET-BN254-G1/1 profile, wallet/EIP-712/passkey
signatures, and either private DH handling or a proof/opening for any public
DH-derived tag. BCC/1 does not add a base-registry condition.
