# Threshold Brief: cand-0012-receipt-renderer

Generated: 2026-06-13T16:45:33Z
Status: validated
Intent: An aac-receipt Lit web component rendering a BalancedVectorReceipt (Design Note 0001 / EVENT-COMPLETE/1): the multi-dimensional vector journal from the shipped P^n conformance vector, balancing per incommensurable dimension (USD/fabric/garment, Dr=Cr per column, no numeraire), with role coverage and proof status. Registered in elements.ts and shown in a new 'The receipt' section of /components.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-receipt.ts` replaces `web/src/components/aac-receipt.ts`: +0/-0 lines vs live
- `cargo/web/src/components/elements.ts` replaces `web/src/components/elements.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/components.mdx` replaces `web/src/content/docs/components.mdx`: +0/-0 lines vs live

## Witnessed behavioral delta (task: aac-receipt component — registers, token-themed, renders a BalancedVectorReceipt balancing per dimension (no numeraire), shown on /components, site builds with it bundled)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
