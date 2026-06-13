# aac queue

The obstruction/backlog queue for this instance. Workers consume the
top open entry (origin-allowlisted) via `bash tools/loop dispatch`.

## Open

- [open] (operator, 2026-06-13) A proof-native double-entry accounting system: entities keep private books, publish provable balanced-claim roots at names, and anchor ledger roots in a registry that refuses unbalanced state — implemented in Noir against the AAC RFC suite, with the core algebra machine-checked in Lean.
- [open] (claude, 2026-06-13) The flake pins `boat` as a local path (`git+file:///Users/arj/irai/boat`), so a judge cloning the repo cannot resolve `nix run .#init` / the governance `nix develop`. Publish a boat ref (or vendor the kernel) before governance reproducibility is part of the judged story. The spec+verification path (`cd sites/ledger/statements && lake …`) is unaffected.
- [open] (claude, 2026-06-13) Web/design track, next: cand-0003 `paint spec-pack` over `sites/ledger/specs` (publish the RFCs as a paintgun spec-publication pack) → cand-0004 the Astro + Starlight site (fresh in-repo) consuming the design/ token CSS → cand-0005 the Lit component library (`aac-record`, `aac-seal`, `aac-stamp`, the proof terminal; the seal-hits-clear-paper layout invariant). Compose the `frontend-design` skill with paintgun for direction.

## Resolved

- [resolved cand-0002-design-tokens, 2026-06-13] Locked the AAC design-token pack — the American Accounting Company design standard (recorded colors, three hands, the measure) as a paint-verified DTCG 2025.10 pack with light + dark ledger schemes, landed into `design/`. Witnessed by `paint build`+`verify` over both schemes, pigment cross-check (incl. dark oxblood brick #ad4a33), corrupted-input rejection. Landed via the loop (snapshot 051c152).
- [resolved cand-0001-establish-ledger-site, 2026-06-13] Established the `ledger` site: relocated the RFC suite → `sites/ledger/specs/` and the machine-checked Pacioli/K(M) statements → `sites/ledger/statements/`, with `pacioli` as the judgment layer. dm.identity relocation, witnessed by byte-identity + relocated-Core.lean elaboration (zero sorry). Landed via the loop (snapshot dd5f362).
