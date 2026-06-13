# Threshold Brief: cand-0002-design-tokens

Generated: 2026-06-13T04:48:37Z
Status: validated
Intent: Lock the AAC design-token pack — the American Accounting Company design standard (recorded colors, three hands, the measure) as a paint-verified DTCG 2025.10 pack with light + dark ledger schemes; the source the spec site and Lit components consume.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=d451104b50d4ab5317c3793d58c2ec18fc541fe6805a5f0e260433ad3f48da8a

## Cargo (what lands if admitted)

- `cargo/README.md` is NEW at `design/README.md`: 77 lines
- `cargo/aac.resolver.json` is NEW at `design/aac.resolver.json`: 39 lines
- `cargo/component-contracts.json` is NEW at `design/component-contracts.json`: 58 lines
- `cargo/tokens/aac.base.json` is NEW at `design/tokens/aac.base.json`: 178 lines
- `cargo/tokens/scheme/dark.tokens.json` is NEW at `design/tokens/scheme/dark.tokens.json`: 237 lines
- `cargo/tokens/scheme/light.tokens.json` is NEW at `design/tokens/scheme/light.tokens.json`: 237 lines

## Witnessed behavioral delta (task: build+verify the AAC design-token pack with paint (both ledger schemes, recorded pigments incl. brick oxblood, corrupted-input rejection))

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
