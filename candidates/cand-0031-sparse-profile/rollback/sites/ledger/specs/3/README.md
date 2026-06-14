# 3/PROOF — Proof Targets and the Verifier Contract

- Name: 3/PROOF · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT.

This specification defines what a proof target is, the three targets the
system **enshrines** (the complete trusted state-transition surface of
4/REG), and the contract a verifier must discharge. Its central rule:

> **A proof conveys nothing in isolation.** The unit of meaning is the
> triple (proof, public inputs, pinned context). A verifier that checks
> fewer than all three has verified nothing and MUST NOT report acceptance.

## 1. Proof system profiles

A target version binds to exactly one profile. Registered profiles:

| profile | definition | role |
|---------|------------|------|
| `uh-bn254/1` | UltraHonk over the BN254 scalar field; universal setup | primary: all client-proved targets |
| `uh-wrap-groth16/1` | a single Groth16 circuit verifying any `uh-bn254/1` proof generically (vk as public input) | reserved settlement tier: one ceremony ever, constant verification cost |

Other profiles MAY be registered. Profile selection is per *target*, not
per system: targets whose statements carry no private witness (e.g. NET/1)
MAY adopt heavier server-side profiles without affecting the client story.
`uh-wrap-groth16/1` is a tier, not a migration: it wraps, and never
replaces, the primary profile, and MUST NOT introduce per-target-version
ceremonies.

## 2. Targets

A **target** is (name, version, profile, ABI, constraint obligations).
A **target instance** is a compiled circuit identified by
(circuit_hash, vk_hash). The pair MUST be pinned wherever the target is
trusted (4/REG §4); provers MUST NOT be the source of either hash.

Targets are content-addressed: `targetId := H(enc(TargetDecl))` over the
declaration (name?, version, profileId, ABI, obligations digest) per
2/FACT §3, so an ABI change *cannot* preserve the identity. Handles like
"TRANSITION/1" are informative.

**ABI freeze rule.** A target version's public-input names, order, and
carrier encodings are immutable; public inputs are carrier scalars of the
target's profile. Any change — including reordering — is a
new version, a new instance, and a new registry entry.

## 3. Constraint idioms (normative for all targets)

Obligations are profile-independent; the mechanism that discharges each
is defined per profile (Annex C).

- **Binarity**: every flag takes exactly the values {0, 1} of the carrier.
- **Implication**: "a ⟹ b" between flags holds as a constraint, not a
  convention.
- **Carrier injectivity**: every admitted amount, and every sum the
  constraints form over admitted amounts, is representable in the carrier
  without wrap. Rationale: the Pacioli relation is decided by carrier
  equality of cross-sums; soundness *is* this injectivity. Removing or
  widening a bound without a new soundness argument is a critical change.
- **Domain separation**: every in-circuit hash invocation carries a
  leading tag unique per (structure, version), assigned in the registry of
  Annex A before use. Tag reuse across structures is a soundness failure.
- **Recomputation**: every public commitment is recomputed in-circuit from
  witnesses and equated to the claimed input. Pass-through public inputs
  (bound by verifier context rather than constraints) MUST be explicitly
  listed in the target's ABI table as `unconstrained`.

## 4. Enshrined targets

The registry trusts exactly three targets, plus one **reserved**
aggregation target (§4.4) whose ABI is fixed now so that batching can be
adopted without a consensus change. Everything else any implementation
proves (statements, disclosures, aggregates) is an **application
target**: useful, versioned the same way, but never a condition of
registry state.

### 4.1 TRANSITION/1

Statement: a private journal, balanced per the deployment's locality
option (1/PACI §3), applied to a committed private state, yields the
committed next state; channel facts emitted by the journal are disclosed
as public outputs in canonical order.

Public ABI (order normative):

| # | name | notes |
|--:|------|-------|
| 0 | prev_account_root | |
| 1 | next_account_root | |
| 2 | prev_nullifier_root | |
| 3 | next_nullifier_root | unchanged unless rights consumed |
| 4 | journal_commitment | recomputed |
| 5 | context_commitment | `unconstrained`; bound by 4/REG context |
| 6 | fact_fold | fold of emitted channel facts, Annex B |
| 7 | fact_count | |

Constraints: journal balance (and entry balance if the profile requires);
state arithmetic (begin + posted = end, per account, per basis); amount
bounds; nullifier insertions for each consumed right with non-membership
of the inserted nullifier; fact_fold recomputed over the emitted facts'
`factId`s in journal order.

### 4.2 NULLIFY/1

Statement: an ordered sequence of nullifier insertions, each inserting a
non-member, connects two roots. Public ABI:
`[first_root, last_root, sequence_commitment, count]`. Intermediate roots
fold into `sequence_commitment`, recomputed in-circuit.

### 4.3 NET/1

Statement: the multiset of channel facts accumulated by the registry over
an epoch nets to zero (1/PACI §4). Public ABI:
`[epoch_id, fold_begin, fold_end, balanced]`. Accumulator soundness
requirements are specified in 5/NET; a NET/1 instance MUST implement one
of the accumulators 5/NET admits and MUST NOT implement a plain field-sum
of digests.

### 4.4 TRANSITION-AGG/1 (reserved)

Statement: each of N child tuples is the public-input vector of a valid
TRANSITION/1 proof, verified in-circuit against the pinned TRANSITION/1
vk. Public ABI: `[transition_vk_hash, child_count, children_commitment]`,
where `children_commitment` is the order-binding fold (Annex B
construction, AGG tag) over the N child tuples, which are supplied to the
registry in calldata and recomputed against the commitment.

Notes (normative): the aggregator role is permissionless and untrusted —
it can batch, it cannot forge; child proofs are public objects, so
aggregation requires no witness access and has no privacy cost; child
*authorization* is NOT proven in-circuit and MUST be carried as per-child
owner authorizations checked by the registry (4/REG §2a). In-circuit
verification is heavy per child; this is a server-side prover role, never
a client obligation.

## 5. The verifier contract

A conforming verifier, in order:
1. Resolves (circuit_hash, vk_hash, verifier instance) for the claimed
   target version from a pinned registry it trusts — never from the prover.
2. Verifies the proof against that vk.
3. Checks **every** public input against independently trusted context:
   stored roots, canonical digests, registry state, or values it computed
   itself. Inputs marked `unconstrained` in the ABI are *only* meaningful
   through this step.
4. For state transitions: checks old roots against current trusted state
   before accepting new roots.

Steps 1–4 are individually mandatory. Implementations SHOULD make the
contract unskippable by construction (e.g., a verifier object that cannot
return acceptance without consuming a context argument).

## 6. Security considerations

Field wraparound (§3, bounding); unconstrained-input misuse (§3, §5.3);
tag collision (Annex A); proof-system profile downgrade (a verifier MUST
reject instances whose profile differs from the pinned one).

## Annex A — Domain tag registry

| range | assignment |
|------:|------------|
| 0–63 | TRANSITION family |
| 64–95 | NULLIFY family |
| 96–111 | NET family |
| 112–119 | TRANSITION-AGG family |
| 120–255 | application targets, first-come via C4 patch |

Assigned tags of deployed instances are recorded in the Deployment
Register (R1), never in this specification.

## Annex B — fact_fold

`fold₀ := H(tag‖"fact_fold/1")`;
`foldᵢ₊₁ := H(tag‖foldᵢ‖factIdᵢ‖sideᵢ‖multiplicityᵢ)` with H the profile
hash and tag from Annex A. The fold is order-binding by design; order is
journal order. (The *netting* accumulator of 5/NET is order-free and
distinct; the fold exists so the registry can cheaply chain what the
epoch proof later nets.)

## Annex C — Profile realizations (informative)

`uh-bn254/1`: carrier is the BN254 scalar field; binarity by x·(x−1) = 0;
implication by a·(1−b) = 0; carrier injectivity by a Field→u64→Field
roundtrip on every amount-bearing witness. Other profiles register their
realizations here by C4 patch.
