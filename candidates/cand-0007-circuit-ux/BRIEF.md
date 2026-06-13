# Threshold Brief: cand-0007-circuit-ux

Generated: 2026-06-13T07:12:59Z
Status: validated
Intent: A /circuit page on the AAC site surfacing the landed TRANSITION/1 Noir circuit (cand-0006): an aac-transition Lit web component rendering the real proven public-input ABI vector (prev/next account+nullifier roots, journal_commitment, fact_fold, context) as a proof receipt with the constraints-discharged checklist, plus prose tying it to 3/PROOF S4.1 and the Core.lean journal_sum_field_sound bound; registered in elements.ts and linked in the sidebar.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=e656d083e825bd60e35c27316fa623f45d838fedecc699a1725b2e9089cb075a

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-transition.ts` replaces `web/src/components/aac-transition.ts`: +0/-0 lines vs live
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/circuit.mdx` replaces `web/src/content/docs/circuit.mdx`: +0/-0 lines vs live
- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +0/-0 lines vs live

## Witnessed behavioral delta (task: aac-transition component + /circuit page — registers, token-themed, renders the TRANSITION/1 ABI, ties to journal_sum_field_sound, site builds with it bundled)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
