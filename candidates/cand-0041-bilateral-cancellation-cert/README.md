# cand-0041-bilateral-cancellation-cert

Intent: Add BCC/1, a bilateral cancellation certificate primitive: two signed opposite committed records, VNET-style zero-sum verification, optional DH edge material, replay/finality tags, executable vectors, and a JS runtime for building/verifying certificates.

## Cargo

- `sites/ledger/specs/applications/BCC-1.md` -- Raw application-target spec for
  the bilateral cancellation certificate primitive.
- `sites/ledger/specs/applications/README.md` -- application-target index row.
- `sites/ledger/specs/applications/vectors/BCC-DEMO-1.json` -- deterministic
  fixture suite for a buyer/seller goods-for-cash cancellation.
- `bcc-runtime/` -- dependency-free ESM runtime with TypeScript declarations and
  tests for building/verifying BCC certificates.

Boundary: this is not a base-registry target and does not replace VNET/1. The
runtime uses deterministic mock commitments/signatures/DH tags for fixture
execution only. Production adapters should replace those seams with the
VNET-BN254 profile, wallet/EIP-712/passkey signatures, and a real DH transcript
proof or private edge-secret handling.

Status: open (pre-threshold).
