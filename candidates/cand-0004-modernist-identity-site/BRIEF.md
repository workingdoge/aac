# Threshold Brief: cand-0004-modernist-identity-site

Generated: 2026-06-13T06:30:10Z
Status: validated
Intent: Pivot the AAC identity and site to the Swiss-modernist direction (the user's brand board): retone the design tokens to the two-colour navy/red palette + Inter, the ledger-cell mark, and a fresh Astro+Starlight site that renders the verified spec pack in the new livery.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=e656d083e825bd60e35c27316fa623f45d838fedecc699a1725b2e9089cb075a

## Cargo (what lands if admitted)

- `cargo/design/README.md` replaces `design/README.md`: +0/-0 lines vs live
- `cargo/design/brand/aac-mark.svg` replaces `design/brand/aac-mark.svg`: +0/-0 lines vs live
- `cargo/design/tokens/aac.base.json` replaces `design/tokens/aac.base.json`: +0/-0 lines vs live
- `cargo/design/tokens/scheme/dark.tokens.json` replaces `design/tokens/scheme/dark.tokens.json`: +0/-0 lines vs live
- `cargo/design/tokens/scheme/light.tokens.json` replaces `design/tokens/scheme/light.tokens.json`: +0/-0 lines vs live
- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +0/-0 lines vs live
- `cargo/web/bun.lock` replaces `web/bun.lock`: +0/-0 lines vs live
- `cargo/web/package.json` replaces `web/package.json`: +0/-0 lines vs live
- `cargo/web/public/favicon.svg` replaces `web/public/favicon.svg`: +0/-0 lines vs live
- `cargo/web/public/logo.svg` replaces `web/public/logo.svg`: +0/-0 lines vs live
- `cargo/web/scripts/sync-specs.mjs` replaces `web/scripts/sync-specs.mjs`: +0/-0 lines vs live
- `cargo/web/src/assets/logo.svg` replaces `web/src/assets/logo.svg`: +0/-0 lines vs live
- `cargo/web/src/content.config.ts` replaces `web/src/content.config.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/index.mdx` replaces `web/src/content/docs/index.mdx`: +0/-0 lines vs live
- `cargo/web/src/styles/custom.css` replaces `web/src/styles/custom.css`: +0/-0 lines vs live
- `cargo/web/tsconfig.json` replaces `web/tsconfig.json`: +0/-0 lines vs live

## Witnessed behavioral delta (task: retone design tokens (navy/red + Inter), the ledger-cell mark (two-colour), and a modernist Astro+Starlight site over the verified spec pack)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
