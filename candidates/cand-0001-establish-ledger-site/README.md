# cand-0001-establish-ledger-site

Intent: Establish the `ledger` site — relocate the RFC suite and the
machine-checked Pacioli/K(M) statements into `sites/ledger/` (`specs/` +
`statements/`), making AAC a first-class boat site parallel to `premath`.
The Pacioli group is its judgment layer.

Status: open (pre-threshold).

## Cargo

18 files landing into a new site `sites/ledger/`:

- `sites/ledger/README.md` — the site framing (category of ledger contexts,
  covers, descent = the registry glue; `pacioli` named as the judgment layer).
- `sites/ledger/specs/` — the RFC suite verbatim (1–8 + 12/OTC, root
  registry README, registers/R1). The site's coverage/admissibility laws.
- `sites/ledger/statements/` — the formal core: `Core.lean` (K(M) machine-
  checked, zero `sorry`) and its self-contained lake project
  (`lakefile.toml`, `lean-toolchain`, `lake-manifest.json`) + the verification
  READMEs.

See `LANDING` for the per-file map.

## Declaration

`layer: artifact` — this is the project's own source (specs + statements),
not boat doctrine/theory/tooling. `preserves: dm.identity` — a pure
relabeling: every file lands byte-identical to its current tracked content;
only its path changes. No semantic object or verdict class is altered.

## Tier

Not tier-sensitive. The LANDING destinations are all under `sites/ledger/`
— a project site, not the law spine (`sites/premath/`) or the verifier set
(`tools/`). The mechanical tier guard (`loop land`) does not require an
independent REVIEW.md for these destinations.

## Evaluation

`eval-self.sh` checks the relocation is faithful and the landed site is
well-formed, in a scratch tree:

- byte-identity: each landed file's sha256 equals its cargo source (dm.identity).
- completeness: the landed `specs/` reproduces the RFC catalog (counts +
  per-number presence); `statements/` carries Core.lean and a buildable lake
  project layout.
- the statements layer still elaborates: `Core.lean` typechecks at its new
  path against the pinned mathlib (zero `sorry`) — the relocation does not
  break the proof.
- rejection probe: a corrupted-copy / missing-file scratch case is refused.

Closes by attesting via `tools/eval/attest.sh`.

## Out-of-band close-out (not LANDED cargo)

Landing is additive. After land, the close-out removes the now-duplicated
originals (`rfc/`, `verification/`) and repoints path references
(`flake.nix` shellHook, top-level `README.md`, `.gitignore` `.lake` path)
at `sites/ledger/statements/`, in the `loop:` close-out commit.
