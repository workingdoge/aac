# VNET/1 — Amount-Vector Netting

- Name: VNET/1 · Status: Raw · **Application target (not enshrined)**
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET.
- Origin: promoted from Design Note 0001 §7's Pedersen vector-commitment sketch.

This specification defines a non-enshrined target for confidential
amount-vector netting across posted state transitions. It proves that a set of
transition-linked debit and credit vectors cancels per basis dimension, using
Pedersen vector commitments whose generators are derived from the declared
basis. It is a policy/admissibility surface: a clearing venue, lender, market,
or settlement workflow MAY require VNET/1, but the base registry MUST NOT make
it a condition of row state.

VNET/1 is distinct from 5/NET. 5/NET nets channel facts over Z[X] by message
identity. VNET/1 nets amount vectors over P^n by basis dimension. A deployment
that needs both MUST verify both; neither proof implies the other.

## 1. Non-redesign boundary

VNET/1 composes with TRANSITION/1; it does not alter TRANSITION/1's public ABI,
replace NET/1, or move Pedersen hashing back into the circuits. TRANSITION/1
continues to recompute `journal_commitment` with the circuit-native hash chosen
for that target. VNET/1 adds a sidecar commitment system for native aggregation:

```
TRANSITION/1   proves one posted journal updates one row's committed state
NET/1          proves emitted channel facts close over an epoch
VNET/1         proves selected posted journals net to zero as amount vectors
```

The sidecar is meaningful only when it is linked to posted transitions. A proof
over unbound Pedersen points is not a VNET/1 proof.

## 2. Vector commitment profile

A VNET/1 profile fixes:

- a prime-order group and canonical point encoding;
- a blinding generator `H`;
- a deterministic generator derivation rule
  `G_j = hash_to_curve("aac/vnet/1", profile_id, basis_commitment, j,
  basis_type_id_j)`;
- subgroup and point-validation rules for every public and witnessed point;
- an amount carrier bound compatible with the referenced TRANSITION/1 profile.

The concrete profile assigned for the reference implementation is
[PEDERSEN-VECTOR/1](../profiles/PEDERSEN-VECTOR-1.md): the Grumpkin group, a
domain-separated try-and-increment generator rule, and an **MSM-only**
aggregation discipline (point addition is not assumed available on the proving
backend; see PEDERSEN-VECTOR/1 §4, §9).

For a non-negative amount vector `v` over basis `B`, the commitment is:

```
Commit_B(v, r) = sum_j v_j * G_j + r * H
```

The profile MUST admit no known discrete-log relation among `H` and any `G_j`.
Generator derivation MUST bind both basis order and basis identity. Two atoms
with different `basis_commitment` or `profile_id` MUST NOT appear in the same
VNET/1 instance.

## 3. Netting atoms

A netting atom is the VNET view of one posted transition journal:

```
VNetAtom := {
  transition_ref:        row_name_or_namehash, nonce, target_id
  journal_commitment:    scalar      # TRANSITION/1 ABI slot 4
  basis_commitment:      scalar
  debit_commitment:      point       # Commit_B(sum debit coordinates, rD)
  credit_commitment:     point       # Commit_B(sum credit coordinates, rC)
  atom_commitment:       scalar      # canonical fold over this record
}
```

`transition_ref` MUST identify a real registry row update whose pinned target is
TRANSITION/1 or an admitted TRANSITION profile. The `journal_commitment` MUST be
the exact public input accepted for that row update.

## 4. The statement

Given a canonical ordered set of `n` atoms, VNET/1 proves:

1. **Transition linkage.** For every atom, the opened debit and credit vectors
   are derived from the same private journal whose circuit-native commitment is
   the atom's `journal_commitment`. A conforming instance MUST either recompute
   the referenced `journal_commitment` in the VNET witness relation or verify a
   companion link proof that binds the Pedersen openings to that exact
   TRANSITION/1 public input. Without this link, the proof is void.
2. **Common basis/profile.** Every atom uses the same `profile_id` and
   `basis_commitment`; basis order and generator derivation are fixed before any
   commitment is interpreted.
3. **Pedersen recomputation.** Every `debit_commitment` and
   `credit_commitment` is recomputed from bounded non-negative coordinates and
   a witnessed blinding.
4. **P^n zero-account.** For every basis dimension `j`,
   `sum_i debit_i,j = sum_i credit_i,j`. No basis dimension may settle another
   one; no price, FX, or scalar valuation enters the target.
5. **Zero opening.** The aggregate point
   `A = sum_i debit_commitment_i - sum_i credit_commitment_i` MUST be proven to
   open to the zero value vector: `A = R * H` for a witnessed aggregate blinding
   `R`. Inspecting that `A` is merely "some point" is insufficient.
6. **Set commitment.** The ordered atom list is bound by an order-binding
   `transition_set_commitment` and an order-binding `commitment_set_commitment`
   so a verifier knows which posted transitions and Pedersen points were netted.

The zero-opening check is the load-bearing rule. Homomorphism only helps because
the value generators cancel to zero and the remaining aggregate has a pure
blinding opening.

## 5. Public ABI (order normative)

| # | name | notes |
|--:|------|-------|
| 0 | `profile_id` | Pedersen vector profile; `unconstrained` but policy-bound |
| 1 | `basis_commitment` | common basis and basis order |
| 2 | `transition_set_commitment` | fold over `(transition_ref, journal_commitment)` atoms |
| 3 | `commitment_set_commitment` | fold over Pedersen point encodings and atom metadata |
| 4 | `aggregate_opening_x` | canonical encoding of `A = sum C_D - sum C_C` |
| 5 | `aggregate_opening_y` | canonical encoding of `A` |
| 6 | `atom_count` | number of atoms netted |
| 7 | `context_commitment` | `unconstrained`; deployment/epoch/policy context |

As in 3/PROOF §5, inputs marked `unconstrained` carry meaning only through the
verifier's context checks. A policy verifier MUST resolve every
`transition_ref` against trusted registry history before reporting acceptance.

## 6. Verifier contract

A conforming VNET/1 verifier, in order:

1. Resolves the target instance and profile from deployment policy, never from
   the prover.
2. Verifies the proof against the pinned instance.
3. Resolves each `transition_ref` against registry history and checks that its
   accepted TRANSITION/1 public input at slot 4 equals the atom's
   `journal_commitment`.
4. Checks `basis_commitment`, `profile_id`, `atom_count`, and
   `context_commitment` against the policy context.
5. Accepts the batch as amount-netted only if the proof verifies and all context
   checks succeed.

The proof alone conveys no settlement authority. It is a confidential netting
certificate over specified posted transitions.

## 7. Rejection requirements

A conforming instance MUST reject:

- a Pedersen commitment not opened by bounded non-negative debit/credit
  coordinates;
- any negative-field or signed-scalar encoding of amounts;
- mixed basis declarations, mixed generator profiles, or ambiguous basis order;
- a zero-opening claim without a witnessed aggregate blinding relation `A = R*H`;
- a netting atom whose Pedersen openings are not linked to the referenced
  TRANSITION/1 `journal_commitment`;
- invalid, non-canonical, small-subgroup, or wrong-curve point encodings;
- duplicate or omitted atoms relative to the committed atom list.

## 8. Security considerations

VNET/1 proves amount-vector closure, not truth, solvency, finality, or fact
closure. It does not prove that the underlying commercial events happened, that
the parties were authorized, or that every emitted channel fact matched a
counterparty fact. EVENT-COMPLETE/1, NET/1, registry root checks, authorization,
and policy remain separate obligations.

The target is intentionally not an admitted 5/NET accumulator in this version.
A future 5/NET amendment MAY admit `pedersen-vector/1` for receipt-aware epochs,
but that would be a separate consensus change. Until then, VNET/1 is an
application target that composes with 5/NET rather than replacing it.

## 9. Implementation status (non-normative)

The concrete vector-commitment profile is assigned:
[PEDERSEN-VECTOR/1](../profiles/PEDERSEN-VECTOR-1.md) (Grumpkin, domain-separated
generator derivation, MSM-only aggregation, zero-opening as a single MSM,
bounded non-negative coordinates). It fixes the group, point encoding, generator
rule, and aggregation discipline VNET/1 §2 left open.

The profile's MSM-only rule is grounded in a measured backend capability: on the
ProveKit WHIR backend the embedded-curve `MultiScalarMul` primitive is available
but `EmbeddedCurveAdd` is not, so all aggregation (including summing committed
points) is expressed as a single multi-scalar multiplication. A toy three-MSM
circuit proved and verified end-to-end on that backend (~15k R1CS constraints,
~1.0 s prove, arm64-darwin), establishing that the homomorphic netting identity
is provable in this substrate.

A reference VNET/1 circuit and its conformance vectors remain the next
implementation slice. Per PEDERSEN-VECTOR/1 §7 the suite MUST cover: accepted
zero-opening, mismatched basis rejection, missing transition-link rejection, an
out-of-bound coordinate rejection, and -- the canonical soundness case -- a
false net rejected even when the aggregate point is well-formed.
