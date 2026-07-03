# PEDERSEN-VECTOR/1 -- Grumpkin Pedersen vector-commitment profile

- Name: PEDERSEN-VECTOR/1 . Status: Raw . Profile for VNET/1 (the §2 profile slot)
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 3/PROOF, VNET/1.
- Origin: concretizes VNET/1 §2/§9, which assigned no group, encoding, or
  generator rule. Profile decisions are constrained by a measured proving-stack
  capability (see §9): the in-circuit primitive available is multi-scalar
  multiplication, not point addition.

This profile fixes a ProveKit-oriented vector-commitment substrate VNET/1 §2
leaves open: the prime-order group, point encoding, generator derivation, and --
the load-bearing constraint of this profile -- the rule that **every aggregation
is expressed as a single multi-scalar multiplication (MSM), never as a sequence
of point additions.**

It does not change VNET/1's statement, ABI, or verifier contract. It binds them
to a substrate that proves on an embedded-curve-MSM backend (the kind ProveKit
exposes; see §9). The existing VNET-BN254-G1/1 profile remains the BN254
reference/JS-verifier substrate; PEDERSEN-VECTOR/1 is the ProveKit circuit
profile. The Poseidon2 identity commitment TRANSITION/1 recomputes is untouched
-- PEDERSEN-VECTOR/1 is the *value* layer, additive alongside it.

## 1. Group and point encoding

| parameter | value |
|---|---|
| group | **Grumpkin** -- the curve whose base field is the BN254 scalar field (the native circuit `Field`) |
| equation | `y^2 = x^3 + b`, `a = 0` |
| order | prime; cofactor 1 (no small-subgroup component) |
| point | affine `{ x: Field, y: Field, is_infinite: bool }` (the Noir `EmbeddedCurvePoint`) |
| scalar | a circuit `Field` value, decomposed to the embedded-curve scalar via the standard `(lo, hi)` split |

Grumpkin is chosen because its base field **is** the circuit's native field, so a
point's coordinates are first-class field elements and the MSM is a native
embedded-curve operation rather than non-native field emulation.

A conforming witness MUST, for every public or witnessed point, enforce that the
point satisfies the curve equation (`y*y == x*x*x + b`) or is the canonical point
at infinity. Cofactor 1 means no separate subgroup check is required; an
on-curve, in-field point is in the prime-order group. Non-canonical, off-curve,
or wrong-`is_infinite` encodings MUST be rejected (VNET/1 §7).

## 2. Generators

PEDERSEN-VECTOR/1 fixes one blinding generator `H` and, for a basis `B` of `n`
dimensions, one value generator `G_j` per dimension.

**Derivation (offline, deterministic).** Generators are derived by domain-
separated try-and-increment hash-to-curve:

```text
seed(label, j) = Poseidon2( "aac/vnet/1", profile_id, basis_commitment,
                            basis_type_id_j, label, j )
G_j  = try_increment( seed("G", j) )       # j in 0..n-1
H    = try_increment( seed("H", 0) )
```

where `try_increment(s)` reads `x = Poseidon2(s, ctr)` for `ctr = 0,1,2,...`,
accepts the first `x` for which `x^3 + b` is a quadratic residue, and takes the
canonically-signed `y`. The rule binds **basis order** (via `j`) and **basis
identity** (via `basis_commitment`, `basis_type_id_j`), as VNET/1 §2 requires.

**Generators are verifier-determined, not prover-chosen.** They are computed
offline by this rule, pinned as **circuit constants** at prepare time, and the
verifier independently re-derives them and confirms they match the pinned
instance and the `basis_commitment` it resolved from policy (VNET/1 §6.1). A
prover MUST NOT be able to substitute generators: witnessed generators would let
a malicious prover choose points with a known discrete-log relation and forge a
zero opening. Pinning them as constants also keeps the MSM cheaper (constant
bases) and avoids in-circuit hash-to-curve.

The profile MUST admit no known discrete-log relation among `H` and any `G_j`;
the independent hash-to-curve derivation discharges this under the random-oracle
heuristic.

## 3. Commitment form

For a non-negative amount vector `v` over basis `B` and blinding `r`:

```text
Commit_B(v, r) = ( sum_{j=0}^{n-1} v_j * G_j ) + r * H
              = multi_scalar_mul( [G_0, ..., G_{n-1}, H], [v_0, ..., v_{n-1}, r] )
```

The commitment is computed by one `multi_scalar_mul` over the `n+1` pinned
generators. This is the only commitment constructor the profile admits.

## 4. MSM-only aggregation (the load-bearing constraint)

The available in-circuit primitive is `multi_scalar_mul`; **point addition is
not available** (see §9). Therefore every aggregation in a PEDERSEN-VECTOR/1
target MUST be expressed as a single MSM. Two consequences:

1. **Summing committed points.** To add committed points `C_0, ..., C_{m-1}`
   (e.g. commitments published by distinct parties), a target MUST compute
   `sum_i C_i = multi_scalar_mul( [C_0, ..., C_{m-1}], [1, ..., 1] )` -- unit
   scalars -- not iterated point additions.
2. **Summing coordinates.** To aggregate raw coordinates a target MUST fold them
   into per-generator net scalars first and emit one MSM (see §5), rather than
   committing each atom and adding the points.

A target MUST NOT rely on a point-addition opcode. A profile implementation that
emits one is outside PEDERSEN-VECTOR/1.

## 5. Zero opening as a single MSM

VNET/1 §4.5 requires the aggregate `A = sum_i C_D,i - sum_i C_C,i` to be proven
to open to the zero value vector, `A = R * H`. Under this profile that proof is:

```text
net_j = sum_i ( debit_{i,j} - credit_{i,j} )          # per basis dimension j
R     = sum_i ( r_D,i - r_C,i )                        # aggregate blinding
A     = multi_scalar_mul( [G_0, ..., G_{n-1}, H], [net_0, ..., net_{n-1}, R] )
```

A conforming target MUST:

1. assert `net_j == 0` for every `j` (the P^n zero-account, VNET/1 §4.4); and
2. recompute `A` by the single MSM above and assert it equals
   `multi_scalar_mul( [H], [R] )` (the pure-blinding opening).

Because `net_j = 0` for all `j`, the value generators cancel and `A = R * H` by
construction; asserting both the per-dimension nullity and the recomputed opening
is what makes the zero opening checkable rather than merely "A is some point"
(VNET/1 §4.5). Credit terms enter as field-negated scalars (`debit - credit`);
this is field subtraction, not a signed-amount encoding (the coordinates
themselves remain bounded non-negative, §6).

## 6. Bounded coordinates

Every debit and credit coordinate, and every blinding, MUST satisfy the carrier
bound of the referenced TRANSITION/1 profile via an explicit RANGE constraint
(3/PROOF Annex C; compatible with SPARSE-CELLS/1 `amount_bound`). Two
obligations follow:

- **No signed encoding.** Coordinates are non-negative; only the derived scalar
  `debit - credit` may be field-negative. A target MUST range-check the
  coordinates, not the differences.
- **No scalar wraparound.** The bound MUST keep every coordinate, and every
  partial sum `sum_i debit_{i,j}`, strictly below the group order, so that
  field-level coordinate arithmetic agrees with integer arithmetic and the
  homomorphism `Commit(v_1) (+) Commit(v_2) = Commit(v_1 + v_2)` holds exactly.
  With a u64 carrier and a realistic atom count this holds with vast margin
  (the group order is ~254 bits).

## 7. Conformance vectors

A conformance suite for a PEDERSEN-VECTOR/1 target MUST include:

- **accept** a true per-dimension zero net with a correct `A = R * H` opening;
- **reject** a false net (some `net_j != 0`) **even when `A` is a well-formed
  curve point** -- the canonical soundness case;
- **reject** a zero-opening claim whose witnessed `R` does not satisfy
  `A == R * H`;
- **reject** an off-curve, non-canonical, or wrong-`is_infinite` point;
- **reject** a mismatched basis / generator set (generators not matching the
  resolved `basis_commitment`);
- **reject** a coordinate outside the carrier bound;
- **reject** an atom whose coordinates do not recompute the referenced
  TRANSITION/1 `journal_commitment` (VNET/1 §4.1 linkage).

## 8. Target identity

A target that adopts PEDERSEN-VECTOR/1 names this profile and its `profile_id`
(`pedersen-vector/1`) in its declaration. Generator derivation, group, and the
MSM-only aggregation rule are part of the target's constraint obligations: a
change to any of them is a new target identity under 3/PROOF, even if the public
ABI names and order (VNET/1 §5) are unchanged.

## 9. Substrate capability and cost (non-normative)

This profile's MSM-only rule (§4) is not an aesthetic choice; it reflects a
measured backend capability. On the ProveKit WHIR backend (worldfnd/ProveKit, an
ACIR -> R1CS -> WHIR stack over Grumpkin), the R1CS compiler implements the
`MultiScalarMul` black-box function and also point addition; a circuit
that emits an embedded-curve addition aborts at compile time. Targets therefore
express all aggregation as MSMs (§4). The same circuit source also proves under
the bb/UltraHonk backend, which does implement point addition; the MSM-only
discipline is the portable subset.

Indicative cost (measured on ProveKit `b0cb124`, `release-fast`, arm64-darwin):
a circuit performing three small Grumpkin MSMs compiled to ~15,000 R1CS
constraints and proved in ~1.0 s, versus ~4,000 constraints / ~0.4 s for a
Poseidon2-hash-only circuit of comparable shape. MSM dominates the constraint
budget, so a target SHOULD minimize MSM term count -- prefer one aggregate MSM
over many per-atom commitments where the linkage permits (§5), and bind
coordinates to the posted transition through the cheap Poseidon2
`journal_commitment` recomputation rather than through redundant Pedersen
recomputation where VNET/1 §4.1 allows.
