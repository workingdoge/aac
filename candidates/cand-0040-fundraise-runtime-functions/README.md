# cand-0040-fundraise-runtime-functions

Intent: Add a function-first JavaScript/TypeScript-facing fundraising runtime that builds and verifies FUNDRAISE-CLEARING/1 packets from typed functions, using the JSON transcript only as a fixture/audit receipt and keeping Python as a reference oracle.

## Cargo

- `fundraise-runtime/package.json` -- package metadata for a dependency-free
  ESM runtime.
- `fundraise-runtime/README.md` -- integration notes for the function-first
  runtime boundary.
- `fundraise-runtime/src/index.mjs` -- function-first JavaScript runtime:
  `createRoundPolicy`, `createSubscription`, report builders,
  `buildFundraisePacket`, `verifyFundraisePacket`, and `authorizeMint`.
- `fundraise-runtime/src/index.d.ts` -- TypeScript declarations for the app and
  CRE/ProveKit integration surfaces.
- `fundraise-runtime/test/run-tests.mjs` -- fixture replay and mutation tests.

The landed `FUNDRAISE-DEMO-1.json` remains an audit/demo receipt and test
fixture. Python remains a reference oracle only; this candidate does not use
Python as the product backend.

Status: open (pre-threshold).
