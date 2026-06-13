# PREMATH-0003: Doctrine — How Structure Descends

Status: generated-and-ported (boat-native condensation of retained doctrine)
Cycle: `boat-2026-05-17`
Surface: `premath.spec.doctrine.v0`

Provenance (sha256 prefix recorded):

```text
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/DOCTRINE-INF.md   6adaa480764336a8
blackhole/fish-2026-05-16/sites/premath/specs/premath/draft/CHANGE-MORPHISMS.md 13d04407355deb9a (concept cited; body ports separately)
```

## 1. Purpose

This is the spec of bringing-down: how abstract structure descends into
implementations, and what each descent step must preserve. Development is a
tower —

```text
L3 doctrine    what KIND of structure (this spec)
L2 theory      a structure described (PREMATH-000x, SIGPI-000x, the charter)
L1 model       the structure realized in a substrate (checkers, loop, Lean, Rust)
L0 evidence    instances of a realization running (traces, scores, witnesses)
```

— and every artifact below the doctrine layer must say which structure it
carries down and what it promises not to break.

Law: DOCT-2.1 — Lower layers MUST publish which doctrine morphism classes
they preserve.

## 2. Doctrine morphism registry (v0)

Law: DOCT-3.1 — Morphism class IDs are stable; v0 defines:

```text
dm.identity                 pure relabeling; preserves semantic object and verdict class
dm.refine.context           context/lineage refinement; preserves meaning under reindex
dm.refine.cover             cover refinement; preserves admissibility class
dm.transport.world          inter-world transport; preserves payload meaning, non-bypass
dm.transport.location       runtime-location transport; preserves run-frame semantics and classification boundaries
dm.profile.execution        execution-substrate change; preserves Gate class outcomes for fixed semantic inputs
dm.profile.evidence         evidence-representation change; preserves verdict + failure classes
dm.policy.rebind            policy/normalizer rebinding; requires new run boundary + witness attribution
dm.presentation.projection  view/UI projection; MAY change representation, MUST NOT change semantic authority
dm.commitment.attest        witness attestation; binds obligations or instruction envelopes to deterministic evidence objects
```

## 3. Preservation declarations

Law: DOCT-4.1 — Artifacts below the doctrine layer MUST carry a
preservation declaration (preserved morphisms; not-preserved with reasons),
and MUST NOT claim preservation for a class unless the artifact's required
invariants make that preservation checkable.

Law: DOCT-5.1 — Satisfaction preservation: a declared morphism
`m : W1 -> W2` preserves a statement `phi` only if
`Sat_W1(phi) => Sat_W2(m(phi))`. For profile morphisms, preserving verdict
class and Gate failure class set is a sufficient v0 criterion.

Law: DOCT-6.1 — `unknown(reason)` is a first-class classification, never an
implicit failure; restrictions on morphisms out of unknown states MUST be
explicitly declared in policy material.

Law: DOCT-8.1 — Doctrine declarations are auditable contract material:
morphism IDs stay stable, declaration changes are decision-logged, and
implementations fail closed when a required preservation claim is missing.

## 4. Governance flywheel profile

Normative only for surfaces explicitly claiming
`profile.doctrine_inf_governance.v0`; surfaces that do not claim it MUST
NOT advertise governance-profile conformance. **Boat's development loop
claims this profile** (see §6).

Law: DOCT-9.1 — Policy provenance binding: governance-sensitive runs MUST
bind explicit policy provenance (pinned flag, package ref, expected digest,
bound digest) and fail closed on unpinned
(`governance.policy_package_unpinned`) or mismatched
(`governance.policy_package_mismatch`) digests.

Law: DOCT-9.3 — Evaluation flywheel evidence: promotion decisions MUST
carry measurable evidence from an evaluation loop — dataset
lineage/provenance, grader/evaluator configuration lineage, and the
decision metrics and thresholds used; unmet thresholds fail closed or
escalate through declared policy.

Law: DOCT-9.4 — Controlled self-evolution bounds: automated improvement
loops MUST declare a bounded retry policy with a terminal condition,
terminal escalation behavior, and a deterministic rollback/revert path with
lineage attribution; the default doctrine posture is that high-risk
governance tiers SHOULD require explicit human checkpoint before
promotion, and where active policy requires it, implementations MUST
enforce it and fail closed when approval evidence is missing.

## 5. Boat-operational realization: the DECLARATION block

The preservation claim format (DOCT-4.1) descends into the candidate store
as a per-candidate `DECLARATION` file:

```text
layer: doctrine | theory | model | evidence-tooling | artifact
implements: <theory surfaces, or none>
preserves: <dm.* list, or none, or unknown(reason)>
compares_to: <sibling models, or none>
```

`loop open` scaffolds it; `loop validate` fails closed on a missing,
incomplete, empty-valued, or out-of-vocabulary declaration, and `loop
auto` refuses candidates that do not validate (DOCT-8.1 brought down).
Declared condensations: the boat block omits the source's
"Not preserved: ... (reason)" half (reasons live in candidate READMEs for
now), and this spec states §8's source SHOULDs as flat law — a declared
strengthening that binds the operating agent tighter. The
development flow this enforces: theory candidates first (laws + fixtures),
then model candidates per substrate against the same fixture corpus, with
comparison evidence between models — descent of one structure along the
substrate cover, coherence checked on overlaps.

## 6. Boat reading (informative): the loop's profile conformance

The loop claims `profile.doctrine_inf_governance.v0`. Current mapping:
9.1 ≈ attestation chain (harness digest bound into scores; INVALID fails
closed); 9.3 ≈ evaluator corpora with provenance hashes, harness hashes,
and verdicts-as-thresholds; 9.4 ≈ `loop rollback` (deterministic, lineage
in LANDED + git snapshots), tier guard as the high-risk checkpoint
(verifier-set cargo requires independent REVIEW), and pralaya as terminal
escalation. Known shortfall, declared: the operator-credential requirement
for the highest tier is an open queue item; until it lands, high-risk
checkpoint enforcement above the review tier is procedural, not mechanical.

## 7. Boundary

This spec does not admit: CHANGE-MORPHISMS' 2-cell calculus (cited,
ports separately); DOCTRINE-INF §9.2 staged guardrail ordering
(pre_flight/input/output stages and risk-tier/observability vocabulary —
runtime-surface material, excluded until a runtime claims it); the layer
stack's original references to TUSK-CORE/SQUEAK/CI specs (not ported); and
any claim that declarations alone establish preservation — they are claims,
checkable per DOCT-4.1, not proofs. Also excluded: the source §7 SHOULD on
doctrine-morphism attribution inside witness diagnostics (revisit when
witness payloads gain structured fields).
