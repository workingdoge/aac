# Threshold Brief: cand-0034-vnet-pedersen

Generated: 2026-06-14T02:09:16Z
Status: validated
Intent: Define VNET/1 as a non-enshrined amount-vector netting target: Pedersen vector commitments per basis, zero-opening proof, and explicit linkage back to posted TRANSITION/1 journal commitments.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/README.md` replaces `sites/ledger/specs/applications/README.md`: +1/-0 lines vs live
- `cargo/sites/ledger/specs/applications/EVENT-COMPLETE-1.md` replaces `sites/ledger/specs/applications/EVENT-COMPLETE-1.md`: +9/-16 lines vs live
- `cargo/sites/ledger/specs/applications/VNET-1.md` is NEW at `sites/ledger/specs/applications/VNET-1.md`:      178 lines

## Witnessed behavioral delta (task: Define VNET/1 as a Raw non-enshrined application target for amount-vector netting across posted TRANSITION/1 journals: Pedersen vector commitments with basis-bound generators, explicit transition journal linkage, aggregate zero-opening proof A=R*H, atom-set commitments, verifier contract/context checks, rejection requirements, and EVENT-COMPLETE/index cross-references. No circuit, registry, or R1 tag allocation.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
