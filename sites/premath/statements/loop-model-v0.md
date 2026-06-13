# Premath Loop Model v0

Statement id: `premath.loop-model.v0`
Owner: Premath (judgment theory: SigPi per `premath.check-sigpi-judgment.v0`)
Status: active for `boat-2026-05-17`

Provenance: boat-native synthesis over landed surfaces only —
PREMATH-0003 §5 (models-compared discipline), PREMATH-0002 §4
(BIDIR-4.4 checking mode), PREMATH-0001 §3.5/§6 + GATE-3.5 (adjoint
declaration rule), `premath.record-judgments.v0` (the adjoint section
that names the missing coherence evidence and this statement's
channel for it), `premath.core.witness-id.v0` (shared wire profile).
The Rust kernel does NOT board with this statement
(imports/receipts/OBSTRUCTION-PREMATH-BULK-RUNTIME-IMPORT-2026-05-16.md
stands).

## Purpose

The bash loop (`tools/loop`) is boat's only model of its own judgment
structure. One model means no coherence evidence: nothing independent
ever predicts what the loop will decide, so the adjoint reading in
`premath.record-judgments.v0` is DECLARED ABSENT and every stone-build
Pi activation (canonicalization, conformance caches, obligation
compilation, fixture reshape, queue store migration) is refused for
lack of exactly this evidence.

This statement introduces the second model: a metacircular evaluator
(`tools/loop-model.py`) that predicts loop verdicts from laws-as-data
(`tools/schemas/loop-laws.json`), run differentially against the live
bash loop (`tools/loop-model-diff.sh`). Agreement between the two
models over the shared fixture corpus and the live candidate store is
the GATE-3.5/Beck–Chevalley-shaped coherence data. The model checks
the loop; it never replaces it.

## Laws

Law: LM-1.1 — compared model, checking mode forever. The loop model is
a COMPARED MODEL per PREMATH-0003 §5: its predictions are proposals in
checking mode (BIDIR-4.4) against the bash loop's verdicts, which
remain the only operative authority. No boat surface may consume a
loop-model prediction as a gate, a verdict, or a capability — in v0
and in every future version, unless a successor STATEMENT (not a tool
landing) re-derives that boundary. A prediction document that leaks
into an authority position is `verifier_contract_violation`.

Law: LM-1.2 — the agreement projection. "The two models agree on a
candidate record" means, surface by surface:

```text
validate        predicted VALIDATE.json byte-identical to the loop's,
                AND predicted exit status (0 admitted / 1 rejected),
                AND predicted post-run META status
scores_verdict  the full output token of the loop's scores_verdict
                contract: pass | "" | MALFORMED-JSON | <json-quoted>
auto            the first refusal point, from the vocabulary:
                refused-unevaluated | refused-verdict-malformed |
                refused-verdict-nonpass | refused-unattested |
                refused-attest-verify | refused-validate |
                refused-already-landed | refused-landing-invalid |
                refused-nothing-to-land | refused-tier-guard | landed
reflect         the assessment token (witness | obstruction-proposal)
                AND the basis line
```

The projection is normative: weakening it (comparing less than the
byte-identical validate document, fewer surfaces, a coarser auto
vocabulary) is a change to THIS LAW, not to the harness. Disagreement
on any surface for any record is a typed refusal,
`model_coherence_failure` (GATE-3.5 shaped, registered in
`tools/schemas/failure-classes.tsv`).

Law: LM-1.3 — laws-as-data is declared redundancy. The model's program
(`tools/schemas/loop-laws.json`) restates the bash loop's judgment
structure as data: the validate law sequence with classes, token
paths, and reason templates; the auto gate chain; the reflect decision
table; the scores_verdict contract. This duplication is DELIBERATE and
load-bearing — the differential is only evidence because the two
models do not share judgment code. Drift between loop-laws.json and
tools/loop is not repaired silently in either direction: it surfaces
as differential disagreement and is reconciled deliberately, like the
verdict-reader tripwire. Shared substrate is confined to RJ-1.6
compiled artifacts both models PARSE as data (status.vocab,
failure-classes.tsv, dispatch-origins.allow, *.schema) and to wire
profiles (`boat.canonical-json.witness-key.v0`, sha256) — sharing an
authority surface or a wire profile is not sharing a judgment.

Law: LM-1.4 — what the coherence evidence is and what it gates.
Coherence evidence is (a) continuous fixture-corpus agreement, run as
an `evaluate-landed` suite member over
`sites/premath/fixtures/loop-model/`, plus (b) whole-store agreement
sweeps recorded at candidate evaluation time. This evidence is the
admission ticket that any stone-build Pi activation refused by the
STONE protocol must cite. It does NOT, by itself, flip
`premath.record-judgments.v0`'s "adjoint support is ABSENT"
declaration: that flip is a law-spine change, operator-held, decided
against accumulated evidence — this statement only builds the channel.

Law: LM-1.5 — ground truth semantics. The bash side of the differential
is the LIVE loop executed in a scratch root (a copy of `tools/`,
`flake.lock`, and the one candidate record under test; never the live
store), surfaces in the order validate, reflect, auto, so earlier
surfaces are captured before later ones mutate the scratch record. The
model side predicts every surface from the pristine record. The
sandbox is part of the projection's meaning: a harness that compared
against mutated state or against the live store would be measuring a
different experiment.

## Boundary

This statement does not admit: any gating power for loop-model output
(LM-1.1 is permanent); modeling of `land`/`rollback`/`record`/`brief`
content or `dispatch` (worker execution, git side effects, and queue
escalation are outside the v0 projection — auto is compared only to
its refusal-point vocabulary); any claim that the two models agree
beyond the corpus actually swept (coverage honesty: the projection is
witnessed per-record, never quantified over futures); independent
reimplementation of wire profiles (witness-id canonicalization and
sha256 are shared substrate by declaration — independence is claimed
at the judgment level, LM-1.3); flipping the GATE-3.5 absence
declaration (LM-1.4 reserves it to the operator); and any boarding of
the archive Rust kernel.
