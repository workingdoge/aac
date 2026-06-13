# aac queue

The obstruction/backlog queue for this instance. Workers consume the
top open entry (origin-allowlisted) via `bash tools/loop dispatch`.

## Open

- [open] (operator, 2026-06-13) A proof-native double-entry accounting system: entities keep private books, publish provable balanced-claim roots at names, and anchor ledger roots in a registry that refuses unbalanced state — implemented in Noir against the AAC RFC suite, with the core algebra machine-checked in Lean.
- [open] (claude, 2026-06-13) The flake pins `boat` as a local path (`git+file:///Users/arj/irai/boat`), so a judge cloning the repo cannot resolve `nix run .#init` / the governance `nix develop`. Publish a boat ref (or vendor the kernel) before governance reproducibility is part of the judged story. The spec+verification path (`cd sites/ledger/statements && lake …`) is unaffected.
- [open] (claude, 2026-06-13) Web/design track, next: cand-0005 the Lit component library (`aac-record`, `aac-stamp`, the proof terminal) themed by the design tokens, dropped into the `web/` site. Optional polish: dark-mode pass, the paintgun fontFamily double-quote bug (file upstream — currently worked around with literal font stacks in `web/src/styles/custom.css`).
- [open] (claude, 2026-06-13) Worldly goal / Noir track: the TRANSITION/1 circuit (journal balance + nullifier + the Field→u64→Field discipline underwritten by `journal_sum_field_sound`). Toolchain wired in flake.nix (bb v2.1.8, noir v1.0.0-beta.14, co-snarks) but `bb` is x86_64-linux-only — needs a Linux prover env (this host is arm64 macOS) before proving works end-to-end.

## Resolved

- [resolved cand-0004-modernist-identity-site, 2026-06-13] Pivoted the AAC identity + site to Swiss-modernist (the user's brand board): retoned `design/tokens/*` to the two-colour navy `#21324F` / red `#93302C` palette + Inter (supersedes cand-0002's Caslon/recorded-colours values), the ledger-cell mark (`design/brand/aac-mark.svg`, the favicon/logo), and a fresh Astro + Starlight site (`web/`) that renders the verified spec pack in the new livery. Witnessed: tokens build+verify, spec-pack verify (11 docs), two-colour mark (navy+red, no gold), web scaffold valid, `astro build` green (13 pages). Landed via the loop (snapshot 9b0d2b6).
- [resolved cand-0003-publish-specs, 2026-06-13] Published the AAC RFC suite as a verified Paintgun spec-publication pack (`atlas.spec-publication.v1` manifest at `sites/ledger/publication.json`, 11 documents over `sites/ledger/specs`). Witnessed by `paint spec-pack` + `verify-spec-pack` (ok:true, checkedDocuments=11), completeness, broken-manifest rejection. Landed via the loop (snapshot 600905c).
- [resolved cand-0002-design-tokens, 2026-06-13] Locked the AAC design-token pack — the American Accounting Company design standard (recorded colors, three hands, the measure) as a paint-verified DTCG 2025.10 pack with light + dark ledger schemes, landed into `design/`. Witnessed by `paint build`+`verify` over both schemes, pigment cross-check (incl. dark oxblood brick #ad4a33), corrupted-input rejection. Landed via the loop (snapshot 051c152).
- [resolved cand-0001-establish-ledger-site, 2026-06-13] Established the `ledger` site: relocated the RFC suite → `sites/ledger/specs/` and the machine-checked Pacioli/K(M) statements → `sites/ledger/statements/`, with `pacioli` as the judgment layer. dm.identity relocation, witnessed by byte-identity + relocated-Core.lean elaboration (zero sorry). Landed via the loop (snapshot dd5f362).
