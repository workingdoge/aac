# VNET Runtime

This package is the JavaScript reference verifier for the landed
`VNET-BN254-G1/1` profile and the transparent transition-link fixture shape.

It ports the dependency-free Python reference logic into product-facing
JavaScript so demos can verify the same BN254 G1 point encodings, generator
derivation, vector commitments, aggregate zero-opening, and transition-link
certificates without shelling out to Python.

It is still a reference/runtime verifier. It is not a Noir circuit, ProveKit
artifact, recursive verifier, Solidity verifier, or production wallet/backend
policy by itself.

Exports:

- `verifyVnetBn254Vector(vnet)`
- `verifyVnetLink(vnetLink)`
- `basisCommitment(basisTypeIds)`
- `certificateFor(atom)`
- `transitionReportFor(vnet)`
