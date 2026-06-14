# BCC Runtime

Function-first JavaScript runtime for BCC/1 bilateral cancellation
certificates.

The product-facing API is:

- `createBilateralEvent`
- `createRecord`
- `createAuthenticatedDh`
- `buildBilateralPacket`
- `buildBilateralCertificate`
- `verifyBilateralCertificate`
- `verifyBilateralPacket`
- `authorizeFinality`
- `demoVectors`

`buildBilateralPacket` returns both a public `certificate` and a
`private_witness`. `verifyBilateralCertificate` checks the public agreement
surface only: commitments, cancellation opening, authenticated ECDH material,
signatures, and replay/finality refs. `verifyBilateralPacket` is a fixture/demo
helper that also checks the private witness against the public commitments.

The demo fixture `BCC-DEMO-1.json` is an audit/conformance receipt. It is not
the app core.

This runtime uses deterministic mock commitments, mock cancellation openings,
mock signatures, and mock authenticated ECDH tags so the fixture suite can
execute without wallet, curve, or proving dependencies. Those mock seams are
explicit and should be replaced by typed Pedersen commitments with aggregate
zero-opening verification, wallet/EIP-712/passkey signatures, and real
authenticated ECDH handling in production.

BCC/1 remains an agreement certificate. Registry admission, private-state
membership/nullifier proofs, bridge custody, mint/burn/release logic, and
deployment-specific predicates belong to the settlement layer above it.
