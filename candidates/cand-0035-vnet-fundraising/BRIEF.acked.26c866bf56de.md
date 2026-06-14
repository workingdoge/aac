# Threshold Brief: cand-0035-vnet-fundraising

Generated: 2026-06-14T02:26:00Z
Status: validated
Intent: Specify FUNDRAISE-CLEARING/1 as a VNET-backed private-balance-sheet fundraising application target: paid subscriptions update private issuer books/cap table and gate restricted token issuance, while concrete VNET curve/profile, circuit, verifier, and vendor adapters remain explicit follow-ons.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/README.md` is NEW at `sites/ledger/specs/applications/README.md	yes`:       21 lines
- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` is NEW at `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md	no`:      248 lines

## Witnessed behavioral delta (task: Define FUNDRAISE-CLEARING/1 as a Raw non-enshrined application target for private-balance-sheet fundraising: paid subscriptions bind to trusted settlement/admissibility reports, private issuer accounting, cap-table root updates, VNET/1 zero-opening over linked TRANSITION/1 journals, subscription nullifiers, and restricted token issuance context. No circuit, contract, external adapter, legal-equity claim, or concrete VNET curve/profile.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
