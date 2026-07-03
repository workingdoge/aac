# Threshold Brief: cand-0087-fundraise-ledger-language

Generated: 2026-06-14T20:37:21Z
Status: validated
Intent: Bind FUNDRAISE-CLEARING/1 and the fundraise demo presentation to LEDGER/1 ledger-state and statement vocabulary.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +111/-46 lines vs live
- `cargo/web/src/content/docs/fundraise.mdx` replaces `web/src/content/docs/fundraise.mdx`: +46/-34 lines vs live
- `cargo/web/src/components/aac-fundraise-demo.ts` replaces `web/src/components/aac-fundraise-demo.ts`: +68/-68 lines vs live
- `cargo/web/src/data/fundraise-demo-summary.ts` replaces `web/src/data/fundraise-demo-summary.ts`: +12/-12 lines vs live

## Witnessed behavioral delta (task: Bind FUNDRAISE-CLEARING/1 and the fundraise demo presentation to LEDGER/1 ledger-state and statement vocabulary.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
