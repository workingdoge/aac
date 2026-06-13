# 7/DATA — Evidence and Availability

- Name: 7/DATA · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 2/FACT.

Books are self-custodied. The chain holds commitments; the entity holds
everything the commitments commit to. This specification defines the
evidence bundle and the duties of entities that make standing claims.

## 1. Bundle and manifest

An **evidence bundle** is content-addressed storage — the binding to a
concrete store is a registered profile (e.g. `data-walrus/1`) — holding: receipts, journals (encrypted at the entity's
discretion), protocol artifacts retained by adapters (2/FACT §5), proof
artifacts, and prior manifests. A **manifest** is a `cjson/1` object
listing (kind, digest, pointer, enc-suite) per item, itself
content-addressed; `aac.data` (6/NAME) points to the current manifest.

## 2. Linkage

Every digest carried inside a fact's `message` MUST appear in some
manifest reachable from the entity's current manifest, for as long as any
standing claim depends on it.

## 3. Loss semantics (normative honesty)

Loss of availability degrades **auditability, never funds**: no asset
custody depends on bundle availability. But a standing claim whose
evidence is unavailable is **unverifiable**, and verifiers MUST treat it
as unproven (not as false). Entities maintaining standing claims MUST
maintain availability of the claims' bundles, SHOULD replicate, and MAY
delegate replication without delegating keys.



