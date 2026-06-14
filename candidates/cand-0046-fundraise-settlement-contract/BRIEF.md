# Threshold Brief: cand-0046-fundraise-settlement-contract

Generated: 2026-06-14T06:45:46Z
Status: validated
Intent: Add a thin authorized-mint settlement contract path for FUNDRAISE-CLEARING/1: runtime emits EVM-shaped mint authorization fields, Solidity verifies signer/round/token/recipient-set/replay, and mints a demo restricted receipt token.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/registry/src/FundraiseSettlement.sol` is NEW at `registry/src/FundraiseSettlement.sol`:      157 lines
- `cargo/registry/test/FundraiseSettlement.t.sol` is NEW at `registry/test/FundraiseSettlement.t.sol`:      122 lines
- `cargo/registry/README.md` replaces `registry/README.md`: +11/-1 lines vs live
- `cargo/fundraise-runtime/README.md` replaces `fundraise-runtime/README.md`: +10/-0 lines vs live
- `cargo/fundraise-runtime/src/index.mjs` replaces `fundraise-runtime/src/index.mjs`: +37/-0 lines vs live
- `cargo/fundraise-runtime/src/index.d.ts` replaces `fundraise-runtime/src/index.d.ts`: +18/-0 lines vs live
- `cargo/fundraise-runtime/test/run-tests.mjs` replaces `fundraise-runtime/test/run-tests.mjs`: +21/-0 lines vs live
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +36/-7 lines vs live

## Witnessed behavioral delta (task: Add runtime EVM mint authorization shaping and a Solidity settlement adapter that verifies authorizer/round/token/recipient-set/replay before minting.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
