# Threshold Brief: cand-0049-provekit-receipt-adapter

Generated: 2026-06-14T07:25:41Z
Status: validated
Intent: Add a dependency-free ProveKit verifier receipt adapter that normalizes accepted ProveKit WHIR/Groth16 proof results into fundraise-workflow verifier receipts, allowing require_live_proof workflows without touching flake/Nix dependencies.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/fundraise-provekit-adapter/package.json` is NEW at `fundraise-provekit-adapter/package.json`:       21 lines
- `cargo/fundraise-provekit-adapter/README.md` is NEW at `fundraise-provekit-adapter/README.md`:       43 lines
- `cargo/fundraise-provekit-adapter/src/index.mjs` is NEW at `fundraise-provekit-adapter/src/index.mjs`:      152 lines
- `cargo/fundraise-provekit-adapter/src/index.d.ts` is NEW at `fundraise-provekit-adapter/src/index.d.ts`:       51 lines
- `cargo/fundraise-provekit-adapter/test/run-tests.mjs` is NEW at `fundraise-provekit-adapter/test/run-tests.mjs`:       75 lines
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +13/-5 lines vs live

## Witnessed behavioral delta (task: Add a dependency-free ProveKit verifier receipt adapter for fundraise-workflow live-proof authorization.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
