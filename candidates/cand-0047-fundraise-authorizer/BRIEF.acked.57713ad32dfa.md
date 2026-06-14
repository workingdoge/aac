# Threshold Brief: cand-0047-fundraise-authorizer

Generated: 2026-06-14T07:05:07Z
Status: validated
Intent: Add a dependency-free fundraise authorizer runtime/CRE-style workflow seam that verifies fundraise packets, binds the EVM mint authorization fields, and emits a deterministic settlement signing request/receipt for the on-chain authorizer role without touching ProveKit or flake tooling.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/fundraise-authorizer/package.json` is NEW at `fundraise-authorizer/package.json`:       21 lines
- `cargo/fundraise-authorizer/README.md` is NEW at `fundraise-authorizer/README.md`:       33 lines
- `cargo/fundraise-authorizer/src/index.mjs` is NEW at `fundraise-authorizer/src/index.mjs`:      281 lines
- `cargo/fundraise-authorizer/src/index.d.ts` is NEW at `fundraise-authorizer/src/index.d.ts`:       96 lines
- `cargo/fundraise-authorizer/test/run-tests.mjs` is NEW at `fundraise-authorizer/test/run-tests.mjs`:       79 lines
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +12/-2 lines vs live

## Witnessed behavioral delta (task: Add a dependency-free fundraise authorizer seam that verifies packets, binds EVM mint authorization, and emits deterministic settlement signing requests/receipts.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
