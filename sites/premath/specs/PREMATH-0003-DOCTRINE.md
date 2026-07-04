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

## 7. Review tiering by claim class

Review tier is classified by the claims a candidate asks the review gate to
discharge, not by the proposer's preference or by the destination path alone.

Law: DOCT-10.1 — Claim-class vocabulary. A `mechanical` claim is one whose
truth is wholly discharged by recorded command runs with stable inputs,
visible outputs, and exit codes. Examples include ancestry checks, digest or
byte equality, declared pin-line changes, generated-file regeneration, and
the existing green check suite. A `semantic` claim is any claim where a human
or LLM reading can add soundness: law, tool behavior, judgment semantics,
review policy, authority boundaries, or any prose whose correctness is not
fully decided by the recorded commands. Unknown or mixed claims are semantic
for review-tier purposes.

Law: DOCT-10.2 — Review tiers. `tier-full` is the existing independent
convened-review path and is unchanged: a fresh reviewer writes a
`ReviewJudgment`, audits the brief and evidence, and may recommend admit,
transform, deny, or needs-more-evidence. `tier-mechanical` is a checklist
path: the candidate's `REVIEW.md` carries a recorded mechanical checklist
that declares each mechanical claim, maps every claim to command run(s),
stores the command outputs and exit codes in the candidate record, and
records the tier-eligibility test. A well-formed `tier-mechanical` checklist
substitutes for convening only for mechanical claims.

Law: DOCT-10.3 — Mechanical-tier refusal rule. A candidate claiming
`tier-mechanical` is REFUSED at review time when its `DECLARATION`,
`LANDING`, or cargo contains any semantic-class change. The mechanically
checkable v0 eligibility test is:

```text
1. every LANDING destination is listed in the checklist's declared
   pin/byte-identity destination allowlist;
2. the diff from the current base file to the candidate seed is classified
   as generated-file, pin-line, or byte-identity only; and
3. the checklist records the eligibility command, output reference, exit
   code `0`, and result `pass`.
```

The checker that consumes review records runs this formation and eligibility
test. Reviewers may rerun or audit it, but the record is not valid unless the
checker accepts it. A semantic destination hidden behind an allowlist, or a
non-pin/generated diff, fails closed as a tier-guard refusal.

Law: DOCT-10.4 — Mechanical checklist formation. A mechanical checklist is
well formed only when all declared claims are mapped to existing command-run
records, every command-run record has a non-empty command, an output
reference inside the candidate record, and exit code `0`, and the
eligibility test is present and passing. Missing mappings, missing outputs,
nonzero exits, malformed eligibility, and ineligible diffs are named
violations and reject the checklist.

Law: DOCT-10.5 — Full-review preservation. Any candidate with a semantic
claim, a mixed claim set, or a malformed mechanical checklist remains on
`tier-full`. This doctrine does not weaken the existing tier guard; it adds
a narrower machine-checkable witness for pin-only, lock-bump, and
digest-verified byte-identity candidates.

## 8. Boundary

This spec does not admit: CHANGE-MORPHISMS' 2-cell calculus (cited,
ports separately); DOCTRINE-INF §9.2 staged guardrail ordering
(pre_flight/input/output stages and risk-tier/observability vocabulary —
runtime-surface material, excluded until a runtime claims it); the layer
stack's original references to TUSK-CORE/SQUEAK/CI specs (not ported); and
any claim that declarations alone establish preservation — they are claims,
checkable per DOCT-4.1, not proofs. Also excluded: the source §7 SHOULD on
doctrine-morphism attribution inside witness diagnostics (revisit when
witness payloads gain structured fields).
