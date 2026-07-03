# Threshold Brief: cand-0090-lineage-reconciliation-record

Generated: 2026-07-03T11:24:55Z
Status: validated
Intent: Record the 2026-07-03 dual-lineage reconciliation (irai-227): merge, queue union, chain repair, kernel restoration
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/sites/ledger/design/0005-lineage-reconciliation-record.md` is NEW at `sites/ledger/design/0005-lineage-reconciliation-record.md`:      177 lines
- `seeds/sites/ledger/design/README.md` replaces `sites/ledger/design/README.md`: +1/-0 lines vs live
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +8/-0 lines vs live

## Witnessed behavioral delta (task: lineage reconciliation record evidence)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
