# aac_vnet_provekit -- VNET/1 on the ProveKit toolchain

This is a standalone Noir beta.19 package for the ProveKit path. It implements
the small demo/reference shape of `VNET/1` under the `PEDERSEN-VECTOR/1` profile:
two posted journal atoms over three basis dimensions, private amount vectors,
public set commitments, and an aggregate zero-opening check.

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

The generator set is fixed inside the circuit as PEDERSEN-VECTOR/1 constants
from `sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json`. The prover
does not supply generators. A verifier re-derives the same constants from the
resolved profile and basis commitment before accepting this target instance.

The proof checks:

- `profile_id_pub`, `basis_commitment_pub`, and `atom_count_pub` match this
  pinned demo instance;
- every coordinate is within the configured profile bound;
- every basis dimension nets to zero across the batch;
- each witnessed `journal_commitments[i]` matches the private atom vector under
  the package's current demo journal fold;
- `transition_set_commitment_pub` folds the witnessed transition refs and
  journal commitments;
- `commitment_set_commitment_pub` folds the recomputed Pedersen debit/credit
  points and atom metadata;
- the public aggregate-opening point equals `sum C_D_i - sum C_C_i`;
- that aggregate point opens as a pure blinding commitment under `H`.

The tests include a negative vector built from the legacy free-label generator
set: that commitment set is rejected because it does not match the pinned
PEDERSEN-VECTOR/1 constants.

## Boundary

This package now implements the VNET/1 commitment/netting public surface for
the demo basis. It does not yet implement the full VNET/1 section 4.1
TRANSITION/1 journal linkage: the package still uses a local demo fold over the
private debit and credit coordinates instead of recomputing the referenced
TRANSITION/1 journal commitment or verifying a companion link proof. That exact
linkage remains a queued follow-up.

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
