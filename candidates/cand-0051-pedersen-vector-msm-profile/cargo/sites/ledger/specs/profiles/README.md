# Ledger profiles

Profiles bind the abstract AAC specifications to concrete representations,
carrier bounds, and proof-target obligations. A profile never changes the
meaning of balance in 1/PACI; it states how a target or implementation carries
that meaning in a concrete substrate.

| Profile | Scope | Status |
|---|---|---|
| [SPARSE-CELLS/1](SPARSE-CELLS-1.md) | Canonical sparse finite-basis amount cells for proof targets | Raw |
| [VNET-BN254-G1/1](VNET-BN254-G1-1.md) | BN254 G1 Pedersen vector commitments for VNET/1 amount-netting atoms | Raw |
| [PEDERSEN-VECTOR/1](PEDERSEN-VECTOR-1.md) | Grumpkin Pedersen vector commitments (MSM-only) for ProveKit VNET/1 targets | Raw |
