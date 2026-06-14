# Threshold Brief: cand-0045-vnet-runtime-adapter

Generated: 2026-06-14T06:24:34Z
Status: validated
Intent: Add a dependency-free JS VNET-BN254/link verifier, wire fundraise-runtime to use it by default, and add a BCC cancellation verifier seam for non-mock profiles.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/vnet-runtime/package.json` is NEW at `vnet-runtime/package.json`:       21 lines
- `cargo/vnet-runtime/README.md` is NEW at `vnet-runtime/README.md`:       21 lines
- `cargo/vnet-runtime/src/index.mjs` is NEW at `vnet-runtime/src/index.mjs`:      326 lines
- `cargo/vnet-runtime/src/index.d.ts` is NEW at `vnet-runtime/src/index.d.ts`:       73 lines
- `cargo/vnet-runtime/test/run-tests.mjs` is NEW at `vnet-runtime/test/run-tests.mjs`:       42 lines
- `cargo/bcc-runtime/package.json` replaces `bcc-runtime/package.json`: +0/-0 lines vs live
- `cargo/bcc-runtime/README.md` replaces `bcc-runtime/README.md`: +17/-3 lines vs live
- `cargo/bcc-runtime/src/index.mjs` replaces `bcc-runtime/src/index.mjs`: +103/-2 lines vs live
- `cargo/bcc-runtime/src/index.d.ts` replaces `bcc-runtime/src/index.d.ts`: +33/-0 lines vs live
- `cargo/bcc-runtime/test/run-tests.mjs` replaces `bcc-runtime/test/run-tests.mjs`: +13/-0 lines vs live
- `cargo/fundraise-runtime/package.json` replaces `fundraise-runtime/package.json`: +0/-0 lines vs live
- `cargo/fundraise-runtime/README.md` replaces `fundraise-runtime/README.md`: +13/-4 lines vs live
- `cargo/fundraise-runtime/src/index.mjs` replaces `fundraise-runtime/src/index.mjs`: +5/-8 lines vs live
- `cargo/fundraise-runtime/src/index.d.ts` replaces `fundraise-runtime/src/index.d.ts`: +13/-0 lines vs live
- `cargo/fundraise-runtime/test/run-tests.mjs` replaces `fundraise-runtime/test/run-tests.mjs`: +58/-1 lines vs live
- `cargo/sites/ledger/specs/applications/BCC-1.md` replaces `sites/ledger/specs/applications/BCC-1.md`: +27/-2 lines vs live
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +11/-8 lines vs live
- `cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json` replaces `sites/ledger/specs/applications/vectors/BCC-DEMO-1.json`: +312/-0 lines vs live

## Witnessed behavioral delta (task: Add JS VNET-BN254/link reference verification, fundraise default VNET verification, and BCC cancellation adapter fail-closed behavior.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
