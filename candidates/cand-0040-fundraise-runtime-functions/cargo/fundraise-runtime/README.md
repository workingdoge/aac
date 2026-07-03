# Fundraise Runtime

This is the JavaScript product seam for the FUNDRAISE-CLEARING/1 demo.

The app should call functions:

- `createRoundPolicy`
- `createSubscription`
- `buildSettlementReport`
- `buildAdmissibilityReport`
- `buildMintAuthorization`
- `buildFundraisePacket`
- `verifyFundraisePacket`
- `authorizeMint`

`FUNDRAISE-DEMO-1.json` is a fixture and audit receipt, not the core runtime.
The Python checker under `sites/ledger/specs/applications/reference/` remains a
reference oracle for conformance. It is not the demo backend.

The expected integration path is:

1. frontend/backend calls these functions to build the fundraising packet;
2. CRE supplies or checks settlement/admissibility reports;
3. ProveKit/native verification replaces the transparent VNET check;
4. `authorizeMint` produces the digest and mint fields a contract path can
   consume.
