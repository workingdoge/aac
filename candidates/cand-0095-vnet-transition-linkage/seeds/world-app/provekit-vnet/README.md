# aac_vnet_provekit -- VNET/1 on the ProveKit toolchain

This is a standalone Noir beta.19 package for the ProveKit path. It implements
the small demo/reference shape of `VNET/1` under the `PEDERSEN-VECTOR/1` profile:
two posted journal atoms over three basis dimensions, private amount vectors,
in-circuit TRANSITION/1 journal-link recomputation, public set commitments, and
an aggregate zero-opening check.

It is not part of the beta.14 `circuits/` workspace. Build the toolchain with:

```sh
nix build .#nargo19
nix build .#provekit
```

## Public ABI

The circuit's public inputs are in the VNET/1 section 5 order:

| # | input |
|--:|-------|
| 0 | `profile_id_pub` |
| 1 | `basis_commitment_pub` |
| 2 | `transition_set_commitment_pub` |
| 3 | `commitment_set_commitment_pub` |
| 4 | `aggregate_opening_x_pub` |
| 5 | `aggregate_opening_y_pub` |
| 6 | `atom_count_pub` |
| 7 | `context_commitment_pub` |

For this demo instance, `profile_id_pub` is `field_of("pedersen-vector/1")` and
`basis_commitment_pub` is the committed PEDERSEN-VECTOR/1 basis commitment for
`["USD", "fabric", "shares"]`. The verifier must still resolve the target,
profile, basis, atom count, and context from policy.

## What The Circuit Proves

For each atom `i`, the witness supplies private debit and credit vectors plus
blindings:

```text
C_D_i = sum_j debit_i[j]  * G_j + r_D_i * H
C_C_i = sum_j credit_i[j] * G_j + r_C_i * H
```

The witness also supplies the TRANSITION/1 journal rows for that atom:

```text
transition_accounts_i[0..3]
transition_debits_i[0..3][0..2]
transition_credits_i[0..3][0..2]
```

The circuit recomputes the canonical TRANSITION/1 journal commitment from
`circuits/ledger` / `circuits/transition`: start with
`Poseidon2([TAG_JOURNAL, 0])`, then fold four rows as
`Poseidon2([TAG_JOURNAL, prior, account, debit_0, debit_1, debit_2,
credit_0, credit_1, credit_2])`, with `TAG_JOURNAL = 3`. It then asserts that
the atom's Pedersen debit and credit vectors are the per-basis sums of those
same private journal rows. This is the VNET/1 section 4.1 in-circuit
recomputation path, not the companion-link-proof path.

The generator set is fixed inside the circuit as PEDERSEN-VECTOR/1 constants
from `sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json`. The prover
does not supply generators. A verifier re-derives the same constants from the
resolved profile and basis commitment before accepting this target instance.

The proof checks:

- `profile_id_pub`, `basis_commitment_pub`, and `atom_count_pub` match this
  pinned demo instance;
- every coordinate is within the configured profile bound;
- every transition journal row account is within this demo TRANSITION/1 account
  domain and every transition row coordinate is within the same bound;
- each witnessed `journal_commitments[i]` equals the canonical TRANSITION/1
  `journal_commitment` recomputed from the private journal rows;
- each atom debit/credit vector is derived as the per-basis sum of those same
  TRANSITION/1 journal rows;
- every basis dimension nets to zero across the batch;
- `transition_set_commitment_pub` folds the witnessed transition refs and
  journal commitments;
- `commitment_set_commitment_pub` folds the recomputed Pedersen debit/credit
  points and atom metadata;
- the public aggregate-opening point equals `sum C_D_i - sum C_C_i`;
- that aggregate point opens as a pure blinding commitment under `H`.
- `context_commitment_pub` is bound to this demo instance's pinned sample
  context value (`9001`), replacing the former ABI-slot self-check.

The tests include a negative vector built from the legacy free-label generator
set: that commitment set is rejected because it does not match the pinned
PEDERSEN-VECTOR/1 constants.

## Boundary

This package implements the VNET/1 commitment/netting public surface and the
VNET/1 section 4.1 in-circuit journal-link relation for the demo basis. It does
not re-prove TRANSITION/1 state roots, nullifier roots, fact folds, or registry
acceptance inside the VNET circuit. As VNET/1 section 6 requires, a verifier
must still resolve each `transition_ref` against trusted registry history and
check that the accepted TRANSITION/1 public input slot 4 equals the atom's
`journal_commitment`.

## Commands

```sh
cd world-app/provekit-vnet
nix run ../..#nargo19 -- test --show-output
cp Prover.toml.example Prover.toml
nix run ../..#nargo19 -- execute
nix run ../..#provekit -- prepare --deny-warnings --force -p aac_vnet_provekit.pkp -v aac_vnet_provekit.pkv .
nix run ../..#provekit -- prove -p aac_vnet_provekit.pkp -i Prover.toml -o proof.np
nix run ../..#provekit -- verify -v aac_vnet_provekit.pkv --proof proof.np
```

The current packaged CLI accepts `.np` or `.json` proof outputs; `.bin` is not a
valid extension.
