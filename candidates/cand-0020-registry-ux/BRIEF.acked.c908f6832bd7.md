# Threshold Brief: cand-0020-registry-ux

Generated: 2026-06-13T18:17:13Z
Status: validated
Intent: A /registry page + aac-row Lit component surfacing 4/REG: the proof-native ledger Row advancing from a TRANSITION/1 proof (real roots prev->next, nonce 0->1, the verifier-contract discharge checklist, the Updated event), tying the on-chain registry to the /circuit proof. Registered in elements.ts, sidebar-linked, verified live in the preview.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-row.ts` replaces `web/src/components/aac-row.ts`: +0/-0 lines vs live
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/registry.mdx` replaces `web/src/content/docs/registry.mdx`: +0/-0 lines vs live
- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +0/-0 lines vs live

## Witnessed behavioral delta (task: aac-row component + /registry page — registers, token-themed, renders a 4/REG row advancing from a TRANSITION/1 proof (old-root equality, refusals), site builds with it bundled)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
