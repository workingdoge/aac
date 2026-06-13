# PREMATH-0000: Sites

Status: generated-and-ported (boat-native condensation of retained doctrine)
Cycle: `boat-2026-05-17`
Surface: `premath.spec.site.v0`

Provenance (extraction per charter import rule; sha256 prefixes recorded):

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/raw/CTX-SITE.md      04dce790773d003e
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/DOCTRINE-SITE.md 7370eeee23e1f581
external reference: https://ncatlab.org/nlab/show/site
```

## 1. Purpose

A **site** is a category equipped with a coverage. This spec fixes that
notion for Boat: every `sites/<name>` plugin is intended to *be* a site —
its own category of contexts, its own covers — and descent over covers is
the discipline by which local admissions glue into global state. Atlas's
chartered vocabulary ("names sites, covers, seams, descent obligations,
global-section claims") is the office-level reading of this spec.

## 2. Base category Ctx

Objects `Gamma` are context slices carrying at least: a stable
`context_id`, a `ctx_ref`, a data head reference, and the parameters
needed for deterministic replay.

Morphisms `rho : Gamma' -> Gamma` are refinement/restriction maps:
`Gamma'` carries at least the constraints and information of `Gamma`, and
all semantic objects admit reindexing along `rho`.

Law: SITE-C.1 — `Ctx` MUST provide identities and closed composition of
refinement morphisms. (Implicit in the source's category structure; made
explicit here.)

Law: SITE-C.2 — `Ctx` SHOULD admit pullbacks up to equivalence: for
`rho : Gamma' -> Gamma` and `sigma : Delta -> Gamma` a deterministic
refinement context realizing `Gamma' x_Gamma Delta`.

## 3. Coverage J

For each context `Gamma`, a **cover** is a family
`U = {rho_i : Gamma_i -> Gamma}` that jointly carries enough information
for global meaning over `Gamma`.

Law: SITE-J.1 — Identity: `{id_Gamma : Gamma -> Gamma}` is a cover.

Law: SITE-J.2 — Base-change stability: the pullback of a cover along any
morphism into `Gamma` is a cover.

Law: SITE-J.3 — Transitivity: covering each leg of a cover by further
covers composes to a cover of the base.

Declared strengthening: the source (raw/CTX-SITE, an informational draft)
states J.1–J.3 as SHOULD. Boat adopts them as normative laws for its own
coverage machinery — a deliberate, declared strength shift, on the grounds
that descent checks are meaningless over a coverage that violates them.

These are the minimum constraints required for descent-style glue checks
(`PREMATH-0001-GATE` laws 3.2–3.4).

## 4. Operational reading

- A cover is the exact decomposition shape an operator (Tusk) is allowed
  to branch work into.
- Overlap compatibility is the local agreement check between branches.
- The global glue is an **admissibility obligation**, never a heuristic:
  failure maps to the Gate failure classes
  (`locality_failure`, `descent_failure`, `glue_non_contractible`).

## 5. Boat reading (informative)

Each `sites/<name>` is a site-in-progress: `sigpi` fixes the judgment and
substitution layer of its contexts; `premath` carries the coverage and
admissibility doctrine itself; `coherence` names the comparison objects
that witness gluing. The development cwf
(`cycles/boat-2026-05-17/statements/premath-development-cwf-v0.md`) is the
fibered layer over this base: candidates are definables over development
states, and admission is comprehension. Cross-site descent — gluing
admissions made locally in different sites into one global state — is the
intended future role of Atlas covers, and is out of scope for v0.

## 6. Boundary

This spec does not admit: an executable site implementation, a cover
store, cross-site descent machinery, topos-level constructions, or any
claim that current Boat sites already satisfy SITE-J.1–J.3. It fixes the
target shape and its laws.

Explicitly excluded from the cited DOCTRINE-SITE source (provenance of the
site-object concept only): canonical map artifacts, required node classes,
edge discipline, map-roundtrip and reachability requirements, and its
conformance tooling. CTX-SITE §6 (minimum-encoding boundary, "no new
authority path") is excluded as runtime-facing.
