# Premath Record Judgments v0

Statement id: `premath.record-judgments.v0`
Owner: Premath (judgment theory: SigPi per `premath.check-sigpi-judgment.v0`)
Status: active for `boat-2026-05-17`

Provenance: boat-native synthesis over landed surfaces only — SIGPI-0001
(judgments, context extension), SIGPI-0003 (Sigma packets), SIGPI-0005
(wire judgments), PREMATH-0001 §3.5/§6 (adjoint declaration rule),
PREMATH-0002 §4 (BIDIR-4.4), PREMATH-0003 §5 (DECLARATION descent),
`premath.regular-doctrine.v0` (atomic predicates; active fragment),
`premath-development-cwf-v0` (receipt/projection correspondence). No
archive text boards with this statement.

## Purpose

Boat's operational records — META, scores.json, QUEUE.md entries, LANDED
manifests, memory/log.jsonl landing records — are today validated by
ad-hoc field checks with no declared types. This statement gives each
record format its judgment in vocabulary the spine has already landed.
One record (DECLARATION) is already typed this way by PREMATH-0003 §5;
this statement extends that precedent to the rest of the store.

The statement introduces NAMES and obligations, not checking power: the
checks it describes are the checks boat already performs, now carrying
declared types and typed failure classes. Executable enforcement beyond
the existing fixture pattern is model-layer work for later candidates.

## Record judgments

Law: RJ-1.1 — META formation (telescope). A candidate META record is a
term of the iterated context extension over the development state:

```text
Gamma_dev, candidate_id : CandId, cycle_id : CycleId,
           opened : Timestamp, intent : Intent, status : StatusVocab ctx
```

per SIGPI-0001 context extension iterated to a telescope. Each required
key is an extension premise; a record missing a required premise fails
formation with the failure class `record-formation-incomplete`. This
class is INTRODUCED HERE: it is deliberately distinct from the landed
`comprehension-missing-evidence` (which means admission attempted
without an evidence term — an absence of witness, not an absence of a
formation premise).

Law: RJ-1.2 — scores as Sigma packet. An evidence record scores.json is
a Sigma introduction per SIGPI-0003: the first component is the verdict
cargo (task, cases, passed, verdict); the second component is the
witness (the attestation provenance block binding harness, traces, and
body). An unattested scores record is a first component without its
witness: failure class `sigma-missing-witness` (the landed class, used
with its landed meaning). The serialized packet does not create
authority; per PREMATH-0002 §8, a proposer's self-assessment cannot
witness its own unattested scores.

Law: RJ-1.3 — QUEUE entries are checking-mode proposals. Every entry in
candidates/QUEUE.md is an untrusted proposal artifact under BIDIR-4.4:
it enters checking mode only, MUST NOT be treated as authored input,
and its claims compile to obligations before any consumer (dispatch
goal selection included) acts on them. Treating a queue entry as
authored is the landed class `verifier_contract_violation`. Operator
intents recorded in the queue remain authored SOURCES, but their queue
serialization is still a wire form a consumer must check, not trust.

Law: RJ-1.4 — landing receipt. A LANDED manifest together with its
memory/log.jsonl landing record realizes the comprehension receipt: it
is the variable `q` of the development CwF correspondence (the receipt
of the last admission), and `loop rollback` realizes the projection
`p`. The log.jsonl prev/hash chain orders receipts; chain order is the
contextuality structure (each receipt = one extension).

Law: RJ-1.5 — vocabulary atoms. Enumerated vocabularies — status values
(StatusVocab), DECLARATION layers (LayerVocab), dm.* tokens (DmToken),
evidence verdicts (VerdictVocab) — board as profile-owned ATOMIC
PREDICATES per the regular-doctrine Atomic Predicates admission route.
They are NOT sum types: disjunction is not active in the regular
fragment. A record carrying an out-of-vocabulary value fails the atom
with failure class `vocabulary-atom-failure`.

Law: RJ-1.6 — wire honesty. The statement is the type; META,
scores.json, QUEUE.md, LANDED, and log.jsonl are wire representations
of judgments (SIGPI-0005), and tools/schemas/*.schema directive files
are COMPILED ARTIFACTS of statements, never executable authority. A
wire format or schema file MUST NOT introduce formation rules.

## The adjoint reading (Sigma builds, Pi verifies, f* transports)

Informative, with one normative declaration.

The development loop realizes the two adjoints of context change around
an approximate reindexing core:

- Sigma (left adjoint) BUILDS CONTEXT: each landing extends the
  development context by one Sigma packet (cargo, witness); the
  candidate store is the telescope; the store accretes by
  Sigma-introduction. Exactness is supplied by content-addressing
  (hashes, attestation, the log chain).
- Pi (right adjoint) VERIFIES RESULTS: laws are Pi-shaped (universally
  quantified over admissible contexts); discharge is the counit — the
  law instantiated at this candidate. Exactness is supplied by
  deterministic, fail-closed gating. Pi is NOT active in the regular
  fragment; today the Pi leg is realized set-level and socially
  (gate, review, operator threshold).
- f* (reindexing) TRANSPORTS: proposer sessions carry meaning across
  contexts. This transport is APPROXIMATE — it is not functorial
  (GATE-3.1 does not hold inside it) — which is precisely why BIDIR-4.4
  places its outputs in checking mode and why both flanks must be
  exact. All transport must be PRESENTED through exact wire forms
  (RJ-1.6) to touch either adjoint.

Laundering failures the loop has caught (verdict smuggling, unattested
self-witnessing, badge laundering) are round trips that minted
authority — violations of the triangle identities this reading demands.

Normative declaration (per PREMATH-0001 GATE-3.5: absent adjoint
support MUST be declared explicitly): **adjoint support is ABSENT.**
No Sigma/Pi adjunction coherence, no Beck–Chevalley compatibility, and
no triangle-identity discharge is claimed by any boat surface. This
reading becomes claimable only when coherence evidence exists between
independent models of the loop over the shared fixture corpus
(the queued loop-model differential); until then it is design language
bounded by this declaration.

Pi has two faces, and the destination is the second: before discharge a
Pi-law is a constraint; after discharge it is an INTERFACE — satisfied
constraints are exactly what makes interaction safe to offer. Typed
capability issuance (origin-binding enforcement, dispatch surfaces,
custody release) is future work gated on the coherence evidence above.

## Boundary

This statement does not admit: an executable record checker beyond the
house required-text fixture pattern; any claim that existing store
records ALREADY satisfy RJ-1.1..1.6 (conformance of the live store is
model-layer evidence, not a statement); any change to loop gating
semantics; sum-type readings of any vocabulary; GATE-4.1 witness
documents for record failures (witness-ID computation has not boarded);
KCIR lowering; and any authority for .schema files (RJ-1.6 forbids it).
The adjoint reading is informative except its absence declaration.
Fixtures under sites/premath/fixtures/record-*.md are textual
conformance (L0); tools/record-judgment-check.sh is required-text
verification in the house pattern, not a kernel.
