# Threshold Brief: cand-0059-web-coherence

Generated: 2026-06-14T10:45:43Z
Status: validated
Intent: Repair web site coherence: publish missing applications/profiles, fix stale internal links, and reorganize navigation around the current demo stack.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/sites/ledger/publication.json` replaces `sites/ledger/publication.json`: +94/-1 lines vs live
- `cargo/web/scripts/sync-specs.mjs` replaces `web/scripts/sync-specs.mjs`: +79/-2 lines vs live
- `cargo/web/astro.config.mjs` replaces `web/astro.config.mjs`: +5/-2 lines vs live
- `cargo/web/src/content/docs/index.mdx` replaces `web/src/content/docs/index.mdx`: +15/-14 lines vs live
- `cargo/web/src/content/docs/components.mdx` replaces `web/src/content/docs/components.mdx`: +8/-5 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +9/-0 lines vs live

## Witnessed behavioral delta (task: Repair web site coherence by publishing missing application/profile docs, fixing stale links, and reorganizing navigation.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
