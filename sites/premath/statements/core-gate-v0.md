# Premath Core Gate v0

Statement id: `premath.core.gate.v0`
Owner: Premath
Status: active for `boat-2026-05-16`

## Purpose

This statement admits the retained `GATE` doctrine as part of Boat's Premath
core.

The Gate gives Premath admissibility outcomes:

```text
accepted
rejected
```

Rejected checks carry deterministic failure classes, including:

- `stability_failure`;
- `locality_failure`;
- `descent_failure`;
- `glue_non_contractible`;
- `adjoint_triple_coherence_failure` when Sigma/Pi support is advertised.

## Source

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/GATE.md
```

## Charter Coherence

This statement gives the threshold-facing predicate vocabulary for admitting or
rejecting semantic claims without making the Gate itself a sovereign threshold
office.

Gate outcomes inform Premath predicate verification. Tusk receipts may record
Gate outcomes, but receipts do not make a rejected claim accepted or an accepted
claim authoritative outside Premath's boundary.

## Boundary

This statement does not admit:

- checker implementation code;
- full-profile conformance machinery;
- fixture suites;
- normalizer or reference-binding substrate;
- Tusk runtime evidence;
- MH final receipts.
