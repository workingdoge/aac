# Threshold Brief: cand-0039-fundraise-demo-packet

Generated: 2026-06-14T03:33:56Z
Status: validated
Intent: Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker that bind round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; include rejection fixtures for price, settlement, token, and VNET failures.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/reference/fundraise_demo.py` is NEW at `sites/ledger/specs/applications/reference/fundraise_demo.py`:      445 lines
- `cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json` is NEW at `sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`:     1909 lines
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +14/-6 lines vs live

## Witnessed behavioral delta (task: Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker binding round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; reject price, settlement, token, and VNET failures.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
