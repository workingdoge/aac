# Premath Core BIDIR Descent v0

Statement id: `premath.core.bidir-descent.v0`
Owner: Premath
Status: active for `boat-2026-05-16`

## Purpose

This statement admits the retained `BIDIR-DESCENT` doctrine as part of Boat's
Premath core.

`BIDIR-DESCENT` separates three phases:

```text
synthesize -> check -> discharge
```

Authored contexts synthesize values and provenance. Target contexts check
claims into obligations. Discharge accepts obligations or rejects with
deterministic witnesses.

## Core Obligation Kinds

The core obligation vocabulary includes:

- `stability`;
- `locality`;
- `descent_exists`;
- `descent_contractible`;
- `adjoint_triple` only when Sigma/f*/Pi support is advertised;
- `ext_gap` and `ext_ambiguous` as operational obligations mapped into Gate
  classes.

## Source

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/BIDIR-DESCENT.md
```

## Charter Coherence

This statement is the strongest fit with Boat's charter because it prevents
proposal text from self-authorizing. Cargo may propose claims, but claims must
compile to obligations and pass discharge before they can function as admitted
semantic evidence.

This keeps Premath predicate authority separate from Atlas placement, Tusk
recording, EVAL execution judgment, and MH receipt packaging.

## Boundary

This statement does not admit:

- NF grammar;
- normalizer implementation;
- reference-binding profile;
- executable BIDIR checker;
- KCIR lowering;
- conformance suites;
- runtime crates or CI machinery.
