# aac queue

The obstruction/backlog queue for this instance. Workers consume the
top open entry (origin-allowlisted) via `bash tools/loop dispatch`.

## Open

- [open] (operator, 2026-06-13) A proof-native double-entry accounting system: entities keep private books, publish provable balanced-claim roots at names, and anchor ledger roots in a registry that refuses unbalanced state — implemented in Noir against the AAC RFC suite, with the core algebra machine-checked in Lean.
- [open] (claude, 2026-06-13) The flake pins `boat` as a local path (`git+file:///Users/arj/irai/boat`), so a judge cloning the repo cannot resolve `nix run .#init` / the governance `nix develop`. Publish a boat ref (or vendor the kernel) before governance reproducibility is part of the judged story. The spec+verification path (`cd sites/ledger/statements && lake …`) is unaffected.

## Resolved

- [resolved cand-0001-establish-ledger-site, 2026-06-13] Established the `ledger` site: relocated the RFC suite → `sites/ledger/specs/` and the machine-checked Pacioli/K(M) statements → `sites/ledger/statements/`, with `pacioli` as the judgment layer. dm.identity relocation, witnessed by byte-identity + relocated-Core.lean elaboration (zero sorry). Landed via the loop (snapshot dd5f362).
