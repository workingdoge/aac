# Fundraise Runtime

This is the JavaScript product seam for the FUNDRAISE-CLEARING/1 demo.

The app should call functions:

- `createRoundPolicy`
- `createSubscription`
- `buildSettlementReport`
- `buildBridgeSettlement`
- `buildAdmissibilityReport`
- `buildMintAuthorization`
- `buildBccAgreements`
- `buildFundraisePacket`
- `verifyFundraisePacket`
- `authorizeMint`

`FUNDRAISE-DEMO-1.json` is a fixture and audit receipt, not the core runtime.
The Python checker under `sites/ledger/specs/applications/reference/` remains a
reference oracle for conformance. It is not the demo backend.

The expected integration path is:

1. frontend/backend calls these functions to build the fundraising packet;
2. investor and issuer co-sign BCC agreement certificates for each subscription;
3. CRE supplies or checks settlement/admissibility and bridge-custody reports;
4. ProveKit/native verification replaces the transparent VNET/private-state check;
5. `authorizeMint` produces the digest and mint fields a contract path can
   consume.

The runtime verifies BCC as an agreement certificate. It still does not prove
private-state membership, nullifier tree updates, bridge custody, or policy
predicates; those remain settlement-layer obligations.

For non-mock BCC signatures, pass `verifyBccSignature` to
`verifyFundraisePacket`. That callback receives the BCC typed-data payload from
`bcc-runtime`; wallet/EIP-712/passkey verification stays outside this package.
