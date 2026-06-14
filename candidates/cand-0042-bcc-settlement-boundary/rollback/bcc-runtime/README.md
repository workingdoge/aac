# BCC Runtime

Function-first JavaScript runtime for BCC/1 bilateral cancellation
certificates.

The product-facing API is:

- `createBilateralEvent`
- `createRecord`
- `createDhEdge`
- `buildBilateralCertificate`
- `verifyBilateralCertificate`
- `authorizeFinality`
- `demoVectors`

The demo fixture `BCC-DEMO-1.json` is an audit/conformance receipt. It is not
the app core.

This runtime uses deterministic mock commitments, signatures, and DH edge tags
so the fixture suite can execute without wallet or proving dependencies. Those
mock seams are explicit and should be replaced by VNET-BN254 commitments,
wallet/EIP-712/passkey signatures, and real DH/proof handling in production.
