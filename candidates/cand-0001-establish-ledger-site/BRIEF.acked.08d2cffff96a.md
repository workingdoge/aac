# Threshold Brief: cand-0001-establish-ledger-site

Generated: 2026-06-13T03:03:08Z
Status: validated
Intent: Establish the ledger site: relocate the RFC suite and the machine-checked Pacioli/K(M) statements into sites/ledger/ (specs/ + statements/), making AAC a first-class boat site parallel to premath; the Pacioli group is its judgment layer.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=50a970057427e8d240542dd425e051e3fc1e968eb56b6a4908a98e8c4091b8e3

## Cargo (what lands if admitted)

- `cargo/README.md` is NEW at `sites/ledger/README.md`: 43 lines
- `cargo/specs/1/README.md` is NEW at `sites/ledger/specs/1/README.md`: 126 lines
- `cargo/specs/12/README.md` is NEW at `sites/ledger/specs/12/README.md`: 288 lines
- `cargo/specs/2/README.md` is NEW at `sites/ledger/specs/2/README.md`: 147 lines
- `cargo/specs/3/README.md` is NEW at `sites/ledger/specs/3/README.md`: 186 lines
- `cargo/specs/4/README.md` is NEW at `sites/ledger/specs/4/README.md`: 118 lines
- `cargo/specs/5/README.md` is NEW at `sites/ledger/specs/5/README.md`: 62 lines
- `cargo/specs/6/README.md` is NEW at `sites/ledger/specs/6/README.md`: 65 lines
- `cargo/specs/7/README.md` is NEW at `sites/ledger/specs/7/README.md`: 35 lines
- `cargo/specs/8/README.md` is NEW at `sites/ledger/specs/8/README.md`: 86 lines
- `cargo/specs/README.md` is NEW at `sites/ledger/specs/README.md`: 92 lines
- `cargo/specs/registers/R1.md` is NEW at `sites/ledger/specs/registers/R1.md`: 39 lines
- `cargo/statements/Core.lean` is NEW at `sites/ledger/statements/Core.lean`: 265 lines
- `cargo/statements/README.md` is NEW at `sites/ledger/statements/README.md`: 61 lines
- `cargo/statements/README_TONIGHT.md` is NEW at `sites/ledger/statements/README_TONIGHT.md`: 90 lines
- `cargo/statements/lake-manifest.json` is NEW at `sites/ledger/statements/lake-manifest.json`: 95 lines
- `cargo/statements/lakefile.toml` is NEW at `sites/ledger/statements/lakefile.toml`: 16 lines
- `cargo/statements/lean-toolchain` is NEW at `sites/ledger/statements/lean-toolchain`: 1 lines

## Witnessed behavioral delta (task: byte-faithful relocation (dm.identity) of the RFC suite and machine-checked statements into sites/ledger/)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
