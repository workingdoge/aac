# PREMATH-0002: Bidirectional Synthesis/Checking with Descent Obligations

Status: generated-and-ported (boat-native condensation of retained doctrine)
Cycle: `boat-2026-05-17`
Surface: `premath.spec.bidir-descent.v0`

Provenance (sha256 prefix recorded):

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/BIDIR-DESCENT.md 2191b04c810cfd80
```

## 1. Purpose

The execution model for full-profile verification, in three phases:

```text
synthesize -> check -> discharge
```

Synthesis on authored contexts produces values plus provenance. Checking
on target contexts produces **obligations** — what must be shown for
admissibility under the Gate. Discharge validates obligations or rejects
with deterministic witnesses. Acceptance is discharge-determined, never
proposal-determined.

## 2. Mode discipline

Let `C` be the full context space and `S ⊂ C` the **authored subset**.

Law: BIDIR-2.1 — Positions in `S` are evaluated in synthesis mode;
positions in `C \ S` in checking mode.

Law: BIDIR-2.2 — Implementations MUST NOT silently treat derived or
checked results as authored inputs.

Law: BIDIR-2.3 — A claimed derived value MUST be traceable to
synthesized authored facts, obligation discharge steps, and the declared
normalization policy (if any).

## 3. Judgments

Synthesis: `Gamma |- t@s ↑ tau ▷ v, p` — deterministic for fixed inputs;
`p` is provenance identifying authored sources.

Checking: `Gamma |- t@c ↓ tau ⇝ (v?, O)` — produces an obligation set
`O`; checking MUST NOT fabricate authored definitions.

Discharge: `Gamma |- O ✓` (accepted) or `Gamma |- O ✗ W` (rejected with
witnesses `W`); witness identifiers and ordering MUST be deterministic.

## 4. Untrusted-proposal ingestion (checking-only)

Law: BIDIR-4.4 — LLM/agent-generated proposal artifacts are untrusted
checking inputs: (1) they enter checking mode only; (2) they MUST NOT be
inserted into the authored subset `S`; (3) their claims MUST compile to
obligations before discharge; (4) acceptance remains
discharge-determined, never proposal-determined.

A BIDIR-4.4 violation precedes the Gate and has no Gate failure class: it
is a verifier contract violation and MUST be rejected deterministically as
such (`verifier_contract_violation`, a boat-operational class).

## 5. Obligation kinds

Law: BIDIR-6.1 — A conforming implementation MUST support obligations
covering at least: `stability` (GATE-3.1), `locality` (GATE-3.2),
`descent_exists` (GATE-3.3), `descent_contractible` (GATE-3.4), and —
only when advertised — `adjoint_triple` (GATE-3.5). The operational
obligations `ext_gap` (no derivation path to a required context) and
`ext_ambiguous` (incomparable maximal derivations) MAY be used and MUST
map into Gate classes deterministically.

Law: BIDIR-6.2 — Each obligation MUST have a deterministic serialization
(kind, serialized ctx, subject, kind-specific details) sufficient to
compute a stable ID.

## 6. Discharge

Law: BIDIR-7.1 — Discharge MUST be deterministic and MUST either accept
or reject with witnesses. In `normalized` mode, compared values MUST be
normalized under the same `(normalizerId, policyDigest)` binding; a
binding mismatch is a deterministic rejection.

Law: BIDIR-8.1 — Gate mapping: `stability -> stability_failure`,
`locality -> locality_failure`, `descent_exists`/`ext_gap ->
descent_failure`, `descent_contractible`/`ext_ambiguous ->
glue_non_contractible`, `adjoint_triple ->
adjoint_triple_coherence_failure`.

## 7. Untrusted surfaces

Law: BIDIR-10.1 — Implementations MUST treat authored inputs,
certificates, stores, and witness payloads as untrusted; they SHOULD
bound recursion and obligation expansion, fail closed on malformed mode
or provenance metadata, and emit deterministic machine-readable error
codes.

## 8. Boat reading (informative)

This spec is the loop's gate, stated as type theory — written in the
predecessor cycle before the loop existed. The correspondence: candidate
cargo and machine-drafted claims are checking-mode inputs (BIDIR-4.4);
briefs and evaluations compile claims into obligations; the evaluator +
attestation chain is a set-level discharge; landing is the admission of a
discharged judgment; and "acceptance is discharge-determined, never
proposal-determined" is precisely why an agent's self-assessment cannot
witness its own unattested scores. The authored subset `S` is the
operator's: intents, threshold decisions, and the charter itself.

## 9. Boundary

This spec does not admit: the normalizer interface (NF/NORMALIZER),
reference binding, KCIR wire formats, witness-ID computation (cited as
required, ported separately), an executable BIDIR checker, or
conformance suites. Laws only.

Explicitly excluded from the source: the Context API requirement (§2.1),
the normalized-mode exposure requirement and witness emission binding of
§5 (meaningful only with a normalizer aboard), semantic-mode requirements
(§7.2), and the Doctrine Preservation Declarations of both sources
(DOCTRINE-INF is not yet ported).
