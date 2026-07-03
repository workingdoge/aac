# aac_vnet_provekit -- VNET/1 on the ProveKit toolchain

This is a standalone Noir beta.19 package for the ProveKit path. It implements
the small demo/reference shape of `VNET/1` under the `PEDERSEN-VECTOR/1` profile:
two posted journal atoms over three basis dimensions, private amount vectors,
public journal-link commitments, Grumpkin Pedersen vector commitments, and an
aggregate zero-opening check.

It is not part of the beta.14 `circuits/` workspace. Build the toolchain with:

```sh
nix build .#nargo19
nix build .#provekit
```

## What The Circuit Proves

For each atom `i`, the witness supplies private debit and credit vectors plus
blindings:

```text
C_D_i = sum_j debit_i[j]  * G_j + r_D_i * H
C_C_i = sum_j credit_i[j] * G_j + r_C_i * H
```

The generator set is fixed inside the circuit using Noir's beta.19
`std::hash::derive_generators` builtin with an AAC VNET domain separator. That
replaces the earlier prototype's known-scalar demo generators.

The proof checks:

- every coordinate is within the configured profile bound;
- every basis dimension nets to zero across the batch;
- each public `journal_commitments_pub[i]` matches the private atom vector;
- the public `transition_set_commitment_pub` folds those journal commitments;
- the public aggregate-opening point equals `sum C_D_i - sum C_C_i`;
- that aggregate point opens as a pure blinding commitment under `H`.

The debit and credit Pedersen commitments are returned as public outputs. They
are the commitments a verifier or clearing venue can bind into the surrounding
fundraise/settlement transcript.

## Boundary

This is the ProveKit proving demo/reference circuit, not the final registry
contract verifier. It composes with the current stack at the transcript boundary:
`journal_commitments_pub` are the transition-link identities, while the proof
shows the selected posted journals clear per basis dimension. A production
deployment still needs the contract/recursive-verifier strategy and a normative
generator-set pinning record beyond this package's circuit hash.

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
