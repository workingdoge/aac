# 6/NAME — Identity Binding

- Name: 6/NAME · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 2/FACT, 4/REG, 7/DATA.

An entity is a name. This specification states what any naming system
must provide to carry entities, charts, and standing claims — and binds
one concrete system as a registered profile.

## 1. Requirements (profile-independent)

A conforming naming system provides:

- **Ownership**: a verifiable controller per name, from which 4/REG
  update authorization derives. Transferring the name transfers the
  books' stewardship; deployments MUST document this consequence.
- **Stable identity**: a digest identity per name (the registry key of
  4/REG), independent of display form.
- **Hierarchy**: sub-names under a name's own authority. The sub-name
  tree SHOULD mirror the chart of accounts; cell-level claims attach to
  sub-names, consolidated claims to the parent.
- **Record slots**: mutable key→value records per name, controller-writable,
  publicly readable.
- **Privacy rule (normative)**: records MUST NOT contain chain or custody
  addresses. The name publishes commitments; custody remains private
  witness. Publishing an address at the name collapses the privacy model
  and is non-conformant.

## 2. Record schema

| key | value |
|-----|-------|
| `aac.registry` | system identifier + registry identifier |
| `aac.claim` | digest of the current standing claim (2/FACT §4 domain) |
| `aac.claim.kind` | typeId of the claim declaration (2/FACT §3) |
| `aac.target` | targetId of the application target proving the claim |
| `aac.data` | 7/DATA manifest pointer for the claim's evidence bundle |
| `aac.enc` | profileIds of the encoding suite in use |

Record *keys* are protocol surface (locations, not identities) and are
fixed by this section; record *values* identify by digest per 2/FACT §3.

## 3. Resolution

To verify a claim from a bare name: resolve records → fetch the evidence
bundle (`aac.data`) → resolve the row (`aac.registry`, name identity) →
discharge the 3/PROOF verifier contract with the row as pinned context →
compare the proven claim digest to `aac.claim`. A resolver that skips the
registry read has verified a self-assertion. Resolvers SHOULD prefer
registry events over records when they disagree, and MUST surface
disagreement.

## 4. Registered profile `name-ens/1`

ENS realizes §1: ownership via the ENS registry/owner (or on-registry
delegation); stable identity via `namehash`; hierarchy via subnames
(`treasury.acme.eth`, `eth.treasury.acme.eth`); record slots via text
records. The 4/REG key is the namehash. Name-security practices of the
profile apply: name hijacking is claim hijacking.

## 5. Security considerations

Name hijacking = claim hijacking (mitigate per profile); stale records
(§3 resolution order); sub-name squatting inside an entity's own tree is
the entity's responsibility.
