# Threshold Brief: cand-0038-vnet-link-verifier

Generated: 2026-06-14T03:18:12Z
Status: validated
Intent: Add a reference VNET link verifier and fixtures: bind VNET-BN254-G1 atoms to accepted TRANSITION/1 registry reports plus companion link certificates, then reject missing transition refs, journal mismatches, link-certificate mismatches, and false nets.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/reference/vnet_link_verifier.py` is NEW at `sites/ledger/specs/applications/reference/vnet_link_verifier.py`:      212 lines
- `cargo/sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json` is NEW at `sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json`:     1336 lines
- `cargo/sites/ledger/specs/applications/VNET-1.md` replaces `sites/ledger/specs/applications/VNET-1.md`: +12/-3 lines vs live

## Witnessed behavioral delta (task: Add a reference VNET transition-link verifier and fixtures: accepted TRANSITION/1 reports, journal_commitment equality, companion link certificates binding opened vectors to transition+basis, and delegation to the VNET-BN254-G1/1 profile checker; reject missing transition refs, journal mismatches, certificate mismatches, and false nets.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
