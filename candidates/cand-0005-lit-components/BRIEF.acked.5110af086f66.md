# Threshold Brief: cand-0005-lit-components

Generated: 2026-06-13T06:42:02Z
Status: validated
Intent: The AAC design system as Lit web components — aac-record (journal voucher), aac-stamp (status), aac-proof (the invariant proof terminal) — themed by the verified design tokens and shown on a /components page in the site.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=e656d083e825bd60e35c27316fa623f45d838fedecc699a1725b2e9089cb075a

## Cargo (what lands if admitted)

- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +0/-0 lines vs live
- `cargo/web/bun.lock` replaces `web/bun.lock`: +0/-0 lines vs live
- `cargo/web/package.json` replaces `web/package.json`: +0/-0 lines vs live
- `cargo/web/src/components/Loader.astro` replaces `web/src/components/Loader.astro`: +0/-0 lines vs live
- `cargo/web/src/components/aac-proof.ts` replaces `web/src/components/aac-proof.ts`: +0/-0 lines vs live
- `cargo/web/src/components/aac-record.ts` replaces `web/src/components/aac-record.ts`: +0/-0 lines vs live
- `cargo/web/src/components/aac-stamp.ts` replaces `web/src/components/aac-stamp.ts`: +0/-0 lines vs live
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/components.mdx` replaces `web/src/content/docs/components.mdx`: +0/-0 lines vs live

## Witnessed behavioral delta (task: Lit web components (aac-record/aac-stamp/aac-proof) — register, token-themed, site builds with them)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
