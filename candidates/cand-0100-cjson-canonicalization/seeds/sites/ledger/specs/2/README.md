# 2/FACT — Attested Facts and Canonical Form

- Name: 2/FACT · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI.

This specification defines the one object that crosses every boundary of
the system, and the bytes it canonically becomes. Balance verdicts (1/PACI)
depend on byte-equality of encoded messages; **the encoding is therefore
semantics**, and it is versioned, total on its grammar, and frozen.

## 1. The attested fact

```
Fact := {
  channel:       typeId            # digest identity of the conservation law (§3)
  side:          "push" | "pull"
  message:       Value             # the conserved object (grammar §2)
  multiplicity:  uint              # ≥ 1
  attestations:  [ Attestation ]   # who vouches
}
Attestation := {
  scheme:  typeId                  # digest identity of the scheme declaration (§3)
  key:     bytes                   # verification key or its digest
  sig:     bytes
}
```

Semantics of a fact are exactly those of a channel fact in 1/PACI §4.
Attestations bind *authorship of the claim*, never its truth (§8).

## 2. Canonical form `cjson/1`

`Value` grammar: `null`, booleans, strings, integers (arbitrary precision),
arrays of Values, objects with string keys and Value members. Floats are
NOT in the grammar; quantities are integers in atomic units (1/PACI §1).

Encoding `enc : Value → bytes` (UTF-8 text):
- `null`, `true`, `false` literally.
- Integers in minimal decimal, optional leading `-`; encoders MUST NOT
  emit `-0`, leading zeros, or exponent forms.
- Strings as JSON strings with mandatory escaping of `"` `\` and
  control characters, and no other escaping; no unpaired surrogates.
  Encoders MUST use the short two-character escapes where JSON defines
  them (`\"`, `\\`, `\b`, `\t`, `\n`, `\f`, `\r`). All other control
  characters MUST be escaped as `\u00xx` with lowercase hex digits. No
  other characters are escaped.
- Arrays: `[` e₁ `,` … `,` eₙ `]`, elements in order, no whitespace.
- Objects: `{` pairs `}`, pairs sorted by the UTF-8 bytes of their keys,
  ascending, duplicate keys forbidden; each pair `enc(key) : enc(value)`;
  no whitespace.

cjson/1 is distinct from RFC 8785/JCS: it sorts object keys by UTF-8
bytes and uses arbitrary-precision minimal decimal integers with no
exponent forms.

Encoders MUST reject any value outside the grammar. `enc` is injective on
the grammar; a collision between distinct Values is a defect of this
specification, not of an implementation.

## 3. Identity by canonical digest

All identity in this suite is the digest of a canonical encoding; string
names are informative handles, never identity.

**Type identity.** A declaration — of a channel, an attestation scheme, a
basis element, a profile, a proof target — is a Value under §2:
`TypeDecl := { kind, name?, version, schema, … }` with `name` informative.
For this suite, a `TypeDecl` MUST be an object with string `kind`,
integer `version`, Value `schema`, and optional string `name`; any
additional member is part of the declaration and changes identity.
Canonical TypeDecl documents for 2/FACT live under
`sites/ledger/specs/2/type-declarations/` and are identified by
`enc(TypeDecl)`, not by source-file whitespace or member order.
Its identity is `typeId := H(enc(TypeDecl))`. Two parties refer to the
same channel iff they hold byte-identical declarations: agreement on an
identifier *is* agreement on its definition, so cross-organization
collisions (two deployments meaning different things by "usdc") are
impossible by construction rather than by convention. Declarations are
evidence, retained and resolvable per 7/DATA; registers (see the index)
MAY map handles to typeIds for human use.

**Instance identity.** `factId := H(enc(fact))` where `fact` is encoded
as the object `{attestations, channel, message, multiplicity, side}`
under §2, with H the registered suite hash of the deployment profile
(e.g. `sha256/1`).

`factId` serves (a) ingestion idempotency — a fact observed twice is the
same fact, not multiplicity two; intentional repetition MUST be expressed
through `multiplicity` or a distinguishing field of `message` — and
(b) the nullifier preimage for consumable rights (1/PACI §5).

## 4. Digest-to-carrier mappings (`d2f` profiles)

Where a digest must enter a proof carrier (3/PROOF), the mapping is a
registered profile: an injective-on-stated-width rule from suite digests
into carrier scalars. Registered: `d2f-31be/1` — for prime carriers
admitting 248 bits, drop the leading byte and interpret the remaining 31
bytes big-endian; the discarded byte MUST NOT carry semantics. All
components of a deployment MUST use the same registered mapping.

## 5. Adapters

External artifacts enter the system only through adapters:

```
adapt : ProtocolArtifact → [ Fact ]
```

Requirements: deterministic; total or explicitly rejecting; the artifact
itself is **evidence**, retained per 7/DATA, with only digests of it
carried inside `message`. An adapter MUST NOT synthesize attestations it
did not verify and MUST map the artifact's own authentication (a receipt
signature, a chip co-signature, a bank's statement seal) into
`attestations` faithfully or not at all.

## 6. Events (attested fact bundles)

An **event** is the bilateral (or multilateral) generalization of a fact:

```
Event := {
  id:            bytes             # shared event identity
  legs:          [ Leg ]           # typed property deltas, per party
  attestations:  [ Attestation ]   # mutual assent over enc(event)
}
Leg := { party, channel: typeId, side, message, multiplicity }
```

One id binds all legs; attestations cover the canonical encoding of the
whole event, so assent is to the *exchange*, not to a leg. Every leg's
`message` MUST include the event id. Adapters derive each participant's
facts from the event's legs; the right to apply a leg is one-shot via
its factId-as-nullifier (§3), which is what scopes the exchange to this
event and this quantity (1/PACI §8). The ratio between legs is witnessed
by the event itself and carries no valuation claim (1/PACI §6).

## 7. Versioning

The encoding version (`cjson/1`), hash (`sha256/1`), and mapping (`d2f-31be/1`)
are carried wherever facts persist or travel. Distinct versions induce
distinct bases of ℤ[X] (1/PACI §4) and MUST NOT be mixed within one
balance computation. Version migration is re-ingestion, not reinterpretation.

## 8. Security considerations

- **Basis collapse.** Any encoder deviation that maps distinct messages to
  equal bytes silently merges conservation lines; treat encoder changes as
  consensus changes and gate them on test vectors.
- **Attestation ≠ truth.** A fact proves who claimed what, with what
  stake; origination-boundary claims (the first assertion that a physical
  or external state is what it is) SHOULD be bonded or multiply attested
  (9/PROV).
- **Identity stuffing.** Because `factId` is the nullifier preimage,
  `message` MUST contain enough distinguishing context (scope, period,
  counterparty) that rights in different scopes cannot collide.

## 9. Conformance

Published test vectors (value → bytes → factId) accompany this
specification; an implementation conforms iff it reproduces all vectors
and rejects all counter-vectors.
