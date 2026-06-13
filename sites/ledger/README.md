# ledger — the AAC site

A boat **site** (PREMATH-0000): a category equipped with a coverage. The
`ledger` site is the AAC domain — proof-native double-entry accounting —
made first-class under governance, parallel to `premath`.

## The site, read categorically

- **Contexts** (`Ctx`) are ledger states: a book at a point, carrying its
  account roots, nullifier roots, and the parameters for deterministic
  replay. Refinement morphisms are restriction/reindexing of one ledger
  context along another.
- **Covers** are decompositions of a global ledger into local books: the
  registry's anchored roots covered by per-entity book roots, an epoch
  covered by its channel-fact legs.
- **Descent** is the discipline that makes AAC AAC: *local balanced
  admissions glue into global balanced state.* The root registry that
  "refuses unbalanced state" is exactly the glue obligation — a failure to
  glue maps to the Gate's `descent_failure` / `glue_non_contractible`
  classes, never a heuristic.

## Layers

Per PREMATH-0000 §5, a site has internal layers. Here:

- **`pacioli` — the judgment layer** (the sigpi-analogue): the Pacioli group
  K(M), the Grothendieck completion of the amount monoid, which fixes the
  judgment and substitution layer of every ledger context. `statements/`
  carries it, machine-checked.
- **coverage / admissibility** — the RFC suite in `specs/`: what a conforming
  ledger MUST admit, and the verifier contract that decides it.

## Contents

- [`specs/`](specs/README.md) — the RFC suite (1–8 + 12/OTC, the root
  registry, registers). Prescriptive: implementations conform to the specs.
- [`statements/`](statements/README.md) — the formal core. `Core.lean`
  machine-checks the K(M) semantics against mathlib (Lean v4.28.0) with zero
  `sorry`, including the field-soundness keystone that a BN254 circuit's
  range checks discharge.

Implementation cargo (Noir circuits, kernels) lands here as it is built; what
survives the gates is what the ledger IS.
