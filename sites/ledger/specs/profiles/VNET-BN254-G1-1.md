# VNET-BN254-G1/1 -- BN254 G1 Pedersen vector commitments

- Name: VNET-BN254-G1/1 . Status: Raw . Profile for VNET/1
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 3/PROOF, VNET/1.

This profile fixes the first concrete Pedersen vector-commitment substrate for
VNET/1 amount-vector netting. It is deliberately small: BN254 G1 points,
deterministic generator derivation, canonical affine encodings, and u64 amount
coordinates compatible with the current TRANSITION/1 amount carrier.

It does not choose a proof system, circuit, verifier contract, settlement
adapter, or token policy. It only defines how VNET/1 interprets and validates
the Pedersen sidecar points that are linked to posted TRANSITION/1 journals.

## 1. Parameters

| parameter | value |
|---|---|
| `profile_handle` | `VNET-BN254-G1/1` |
| `profile_id` | `vnet-bn254-g1/1` |
| group | BN254 G1, short Weierstrass `y^2 = x^3 + 3` |
| base field `p` | `21888242871839275222246405745257275088696311157297823662689037894645226208583` |
| scalar field `r` | `21888242871839275222246405745257275088548364400416034343698204186575808495617` |
| amount bound | every coordinate is an integer `0 <= v < 2^64` |
| scalar interpretation | amount coordinates and blindings are interpreted modulo `r`; amounts MUST NOT wrap |
| point encoding | uncompressed affine `0x04 || x_be32 || y_be32`; infinity is not encodable |

The point at infinity is not a valid public or witnessed commitment point in
this profile. Honest provers MUST choose blindings so the aggregate opening
point `A = R*H` is not infinity. A future profile MAY define an infinity
encoding if a deployment needs it.

## 2. Canonical point validation

A conforming verifier MUST reject any point unless all of the following hold:

1. The encoding is exactly 65 bytes: prefix `0x04`, followed by 32-byte
   big-endian `x` and `y`.
2. `x < p` and `y < p`.
3. `(x, y)` satisfies `y^2 = x^3 + 3 mod p`.
4. The point is in the prime-order subgroup. A verifier MAY discharge this
   by a profile-specific proof that BN254 G1 has the required cofactor
   property, or by checking `[r]P = O`.

## 3. Generator derivation

Generators are derived by try-and-increment hash-to-curve:

```text
H   = hash_to_curve("aac/vnet-bn254-g1/1/H", profile_id, basis_commitment)
G_j = hash_to_curve("aac/vnet-bn254-g1/1/G", profile_id,
                    basis_commitment, j, basis_type_id_j)
```

The hash input is the canonical JSON array of the label and arguments, encoded
as UTF-8 with sorted object keys and no insignificant whitespace. For counter
`c = 0, 1, 2, ...`, compute:

```text
x_c = SHA-256(canonical_input || uint32_be(c)) mod p
rhs = x_c^3 + 3 mod p
```

The first `c` whose `rhs` is a quadratic residue is accepted. The `y`
coordinate is the even square root of `rhs`; if the square root has odd least
significant bit, use `p - y`. The resulting affine point is the generator.

The profile MUST admit no known discrete-log relation among `H` and any `G_j`.
Generator derivation binds `profile_id`, `basis_commitment`, basis order, and
every `basis_type_id_j`; a commitment from one basis declaration cannot be
reused in another.

## 4. Basis commitment

For conformance fixtures and reference checkers, the basis commitment is:

```text
basis_commitment =
  SHA-256(["aac/vnet-bn254-g1/1/basis", profile_id, basis_type_ids]) mod r
```

where `basis_type_ids` is the ordered list of basis identifiers. A production
target MAY replace this hash with the deployment's canonical 2/FACT encoding,
but then the target identity changes unless the replacement is already declared
in its obligations digest.

## 5. Commitment rule

For a non-negative amount vector `v` over a declared basis and blinding `rho`:

```text
Commit_B(v, rho) = rho*H + sum_j v_j*G_j
```

Every `v_j` MUST be below the amount bound before it is interpreted as a scalar.
Signed field elements and negative encodings are invalid. Debit and credit
vectors are committed separately; signed accounting remains the 1/PACI pair
`(debit, credit)`, never a negative scalar.

## 6. VNET atom validation

A VNET-BN254-G1/1 atom is valid only if:

1. its `profile_id` equals `vnet-bn254-g1/1`;
2. its `basis_commitment` equals the declared ordered basis;
3. its debit and credit points are canonical BN254 G1 encodings;
4. its debit and credit points recompute from witnessed bounded coordinates and
   blindings;
5. its openings are linked to the exact TRANSITION/1 `journal_commitment` named
   by the atom.

The profile does not define that link proof. VNET/1 requires either
recomputing the referenced journal commitment in the VNET witness relation or
verifying a companion link proof.

## 7. Aggregate zero opening

For an ordered atom set:

```text
A = sum_i C_D_i - sum_i C_C_i
R = sum_i rho_D_i - sum_i rho_C_i mod r
```

The verifier accepts the amount-vector net only if `A = R*H` and every basis
coordinate's debit total equals its credit total. A well-formed aggregate point
without the witnessed `R` relation is not a zero-opening proof.

## 8. Conformance vectors

The profile's initial conformance suite is
[`vectors/VNET-BN254-G1-1.json`](vectors/VNET-BN254-G1-1.json), checked by
[`reference/vnet_bn254_g1_1.py`](reference/vnet_bn254_g1_1.py). It covers:

- accepted fundraising batch;
- mismatched basis rejection;
- missing transition-link rejection;
- false net rejected by the zero-opening relation even when every point is
  well-formed.

## 9. Security considerations

This profile is not a promise that BN254 G1 is the final production choice for
every deployment. It is the first executable VNET substrate because it is close
to the current BN254 proof stack and EVM verification surfaces. A future profile
may choose another group, encoding, or hash-to-curve suite; such a change is a
new profile identity.
