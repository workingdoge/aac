# Threshold Brief: cand-0048-fundraise-workflow

Generated: 2026-06-14T07:12:37Z
Status: validated
Intent: Add a dependency-free fundraise workflow core that composes ProveKit/CRE verifier receipts with the fundraise authorizer seam, producing deterministic settlement actions for FundraiseMintSettlement without touching flake/Nix dependencies.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/fundraise-workflow/package.json` is NEW at `fundraise-workflow/package.json`:       21 lines
- `cargo/fundraise-workflow/README.md` is NEW at `fundraise-workflow/README.md`:       38 lines
- `cargo/fundraise-workflow/src/index.mjs` is NEW at `fundraise-workflow/src/index.mjs`:      267 lines
- `cargo/fundraise-workflow/src/index.d.ts` is NEW at `fundraise-workflow/src/index.d.ts`:      123 lines
- `cargo/fundraise-workflow/test/run-tests.mjs` is NEW at `fundraise-workflow/test/run-tests.mjs`:       78 lines
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +13/-4 lines vs live

## Witnessed behavioral delta (task: Add a dependency-free fundraise workflow core that composes verifier receipts with the authorizer seam and emits settlement actions.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
