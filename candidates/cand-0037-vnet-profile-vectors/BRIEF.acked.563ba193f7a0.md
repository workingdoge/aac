# Threshold Brief: cand-0037-vnet-profile-vectors

Generated: 2026-06-14T03:04:31Z
Status: validated
Intent: Define the first concrete VNET/1 profile and conformance vectors for fundraising batch netting: BN254/G1 Pedersen vector commitments, canonical point encoding, deterministic hash-to-curve generator derivation, a reference checker, and accepted/rejected fixtures for zero-opening, basis mismatch, transition-link omission, and false net.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/profiles/README.md` replaces `sites/ledger/specs/profiles/README.md`: +1/-1 lines vs live
- `cargo/sites/ledger/specs/profiles/VNET-BN254-G1-1.md` is NEW at `sites/ledger/specs/profiles/VNET-BN254-G1-1.md`:      148 lines
- `cargo/sites/ledger/specs/profiles/reference/vnet_bn254_g1_1.py` is NEW at `sites/ledger/specs/profiles/reference/vnet_bn254_g1_1.py`:      361 lines
- `cargo/sites/ledger/specs/profiles/vectors/VNET-BN254-G1-1.json` is NEW at `sites/ledger/specs/profiles/vectors/VNET-BN254-G1-1.json`:      630 lines
- `cargo/sites/ledger/specs/applications/VNET-1.md` replaces `sites/ledger/specs/applications/VNET-1.md`: +10/-5 lines vs live

## Witnessed behavioral delta (task: Define VNET-BN254-G1/1 as the first concrete VNET/1 Pedersen vector-commitment profile, with BN254 G1 point encoding, deterministic generator derivation, u64 amount bounds, executable generated conformance vectors, and a reference checker covering accepted fundraising batch, mixed-basis rejection, missing transition-link rejection, and false-net zero-opening rejection.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
