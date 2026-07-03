# cand-0037-vnet-profile-vectors

Intent: Define the first concrete VNET/1 profile and conformance vectors for fundraising batch netting: BN254/G1 Pedersen vector commitments, canonical point encoding, deterministic hash-to-curve generator derivation, a reference checker, and accepted/rejected fixtures for zero-opening, basis mismatch, transition-link omission, and false net.

## Cargo

- `sites/ledger/specs/profiles/VNET-BN254-G1-1.md` -- concrete Raw
  Pedersen vector-commitment profile for VNET/1.
- `sites/ledger/specs/profiles/README.md` -- profile index row.
- `sites/ledger/specs/profiles/reference/vnet_bn254_g1_1.py` -- reference
  generator/checker for the profile's fixture format.
- `sites/ledger/specs/profiles/vectors/VNET-BN254-G1-1.json` -- generated
  conformance vectors: accepted fundraising batch, mismatched basis rejection,
  missing transition-link rejection, and false-net zero-opening rejection.
- `sites/ledger/specs/applications/VNET-1.md` -- implementation-status
  cross-reference to the profile and vectors.

No VNET circuit, on-chain verifier, ProveKit integration, or contract code is
included in this slice.

Status: open (pre-threshold).
