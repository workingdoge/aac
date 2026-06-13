# PREMATH-0001: The Gate

Status: generated-and-ported (boat-native condensation of retained doctrine)
Cycle: `boat-2026-05-17`
Surface: `premath.spec.gate.v0`

Provenance (sha256 prefix recorded):

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/GATE.md 16d245637737ef08
```

## 1. Purpose

The Gate is Premath's admissibility judgment: **a notion is admissible
exactly when it is stable under context change and glues uniquely from
locally compatible data**. A judgment `Gamma |- A` is Gate-valid iff all
laws in §3 hold.

## 2. Constructor interface

A constructor is a tuple `K = (C, Cov, Def, ~, Reindex, Sigma, Pi)`:

- `C` — a category of contexts (a site base, per PREMATH-0000-SITE);
- `Cov` — a coverage on `C`;
- `Def` — indexed definables: for each `Gamma`, the space `Def(Gamma)`
  with reindexing `f* : Def(Gamma) -> Def(Gamma')`;
- `~` — the constructor's sameness relation (equality, isomorphism, or
  higher equivalence; all laws are stated up to `~`);
- `Sigma`, `Pi` — optional context-change pushforwards.

## 3. Admissibility laws

Law: GATE-3.1 — Stability (functorial reindexing). For every
`f : Gamma' -> Gamma`, `g : Gamma'' -> Gamma'`:
`(id_Gamma)* A ~ A` and `(f o g)* A ~ g*(f* A)`.
A claimed admissible judgment failing either MUST be rejected.

Law: GATE-3.2 — Locality (cover restriction). For every cover
`U = {u_i : Gamma_i -> Gamma}` in `Cov(Gamma)`, each restriction
`u_i* A` MUST exist. Claims that cannot be restricted along a declared
cover MUST be rejected.

Law: GATE-3.3 — Descent (gluing existence). Given a cover `U` over
`Gamma`, locals `A_i in Def(Gamma_i)`, and overlap compatibilities
`phi_ij : p1* A_i ~ p2* A_j` satisfying cocycle coherence, at least one
global `A in Def(Gamma)` with compatible restrictions MUST exist.

Law: GATE-3.4 — Stack-safe uniqueness (contractible glue space).
`Glue(U; A_i, phi_ij)` MUST be contractible: unique glue up to unique
`~`. Set-level implementations MAY realize this as exactly one result
modulo equality; higher-level implementations MUST provide coherent
uniqueness at their level.

Law: GATE-3.5 — Adjoint triple coherence (Sigma/Pi). When `Sigma_f` and
`Pi_f` are provided: `Sigma_f -| f* -| Pi_f` up to `~` with explicit
coherence data, Beck–Chevalley compatibility on pullback squares, and
descent-compatibility with gluing/restriction. Advertised adjoint support
with failed coherence MUST be rejection; absent support MUST be declared
explicitly in conformance output.

## 4. Gate result and witnessing

A Gate check MUST produce `accepted` (with law witnesses) or `rejected`
with at least one failing class from:

```text
stability_failure | locality_failure | descent_failure
| glue_non_contractible | adjoint_triple_coherence_failure
```

Law: GATE-4.1 — Witness format. Rejections MUST emit a JSON document with
`witnessSchema` (currently 1), `profile`, `result: "rejected"`, and a
`failures` array whose entries each carry a deterministic `witnessId`, a
`class` from §4, a `lawRef` (e.g. `GATE-3.1`), and a `message`; witness
arrays MUST be deterministically ordered by
(class, lawRef, tokenPath?, context?, witnessId).

## 5. Boat reading (informative)

Boat's verifier suite is a set-level proto-Gate: schema/fixture checkers
realize crude locality (does the claim restrict to each required field
surface?) and the attestation chain realizes a crude witness discipline.
The existing fixtures `regular-doctrine-reindexing-laws-v0` (GATE-3.1)
and `toy-adversarial-descent-failure-bad-constant-v0` (GATE-3.3/3.4,
toy profile) predate this spec and are claimed by it.

## 6. Boundary

This spec does not admit: a normalizer, NF grammars, KCIR lowering, the
executable toy or kernel checkers (separate candidates), or conformance
suites. Laws only.

Explicitly excluded from the source: the operational constructor-interface
MUSTs of GATE §2.1–2.4 (cover membership/overlap/pullback operations and
judgment-check APIs — summarized informatively in §2 here, normative only
in an implementation candidate); the `profile: "full"` witness field
(boat checkers declare their own profile strings); and witness-ID
computation, which is `draft/WITNESS-ID` and ports separately.
