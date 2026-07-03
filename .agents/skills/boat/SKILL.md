---
name: boat
description: >-
  Use when work in this repo must pass through the Boat governed development
  loop — proposing candidates, building attested evidence, briefing, independent
  review, landing, rollback, or dispatch. Boat is the local authority on
  candidate lifecycle, discharge-determined acceptance (BIDIR-4.4), evidence
  attestation, tier guards, and the obstruction queue. This is the kernel skill:
  every tool it names is part of the export kernel, so it is accurate in the
  source instance and in every instance born from boat-init alike. Also use it
  when KB, OKF, semantic-envelope, receipt-memory, source-adapter,
  checked-carrier, or memory-chain projection work must enter Boat as governed
  seed material without turning Boat into KB, OKF, or Harbor authority.
---

# Boat

This repo is a governed development loop: every change is a candidate,
evaluated against attested evidence, briefed, reviewed, and gated before it
lands. Acceptance is discharge-determined, never proposal-determined
(BIDIR-4.4): what a proposer claims carries no authority; what the verifier
set discharges does.

If `EXPORT-RECEIPT.md` is present, this is an instance born from `boat-init`:
it carries the loop kernel and the discipline laws, not the source's history.
The project being built here enters as candidates like everything else.

Use this skill when the work is about:

- proposing a change to this tree (everything is a candidate; direct edits to
  `tools/` or `sites/` bypass the constitution — never make them);
- building functional evidence in scratch trees and attesting it
  (`tools/eval/attest.sh write scores.json eval-self.sh traces` — unattested
  evidence cannot witness);
- briefing a decision-maker (`loop brief`), acking a brief
  (`--ack-latest`), or landing with a git snapshot (`loop land`);
- convening an independent reviewer in a SEPARATE fresh Claude or Codex session
  (`loop review` generates REVIEW-PROMPT.md; never review your own candidate
  in your own context; at most 2 transform rounds — this bound is CONTROLLING);
- dispatching bounded worker sessions
  (`loop dispatch --agent NAME [--goal G] [--worker claude|codex|auto]
  [--max-attempts N] [--budget-usd X]`) whose outcomes are verified against
  the store, not worker self-report (ROUTE-1.2);
- consuming or feeding the obstruction queue (`candidates/QUEUE.md`);
- bounding that queue as working memory — `tools/queue-archive.sh` moves resolved entries out of the working set into an archive and warns when the open backlog grows past a soft bound, keeping the agent's context small;
- routing KB, OKF, semantic-envelope, receipt-memory, source-adapter,
  checked-carrier, or memory-chain projection work through candidate seeds
  while preserving KB admission and Harbor readiness frontiers;
- rolling back a landing (`loop rollback` — evidence is retained).

## The contract

Read `WORKER.md` at the repo root before doing anything. It is the binding
proposer contract. Non-negotiables:

- The tier guard stands: no landing into `tools/` (or the law spine under
  `sites/premath/`) without an independent REVIEW.md. Do not weaken any rail
  to make a candidate pass.
- Declare your candidate's tower position (DECLARATION: layer / implements /
  preserves / compares_to, dm.* registry vocabulary, PREMATH-0003 §5).
  Validate fails closed without it.
- Whatever WORKER.md marks operator-held is never yours to write — queue it,
  never touch it.

## The iteration shape

```
bash tools/loop open cand-NNNN-name "intent"
# fill DECLARATION; build seeds/... + LANDING map in the candidate dir
bash tools/loop validate cand-NNNN-name
bash candidates/cand-NNNN-name/eval-self.sh     # must end by attesting
bash tools/loop brief cand-NNNN-name
bash tools/loop review cand-NNNN-name           # if LANDING touches tools/ or premath specs
bash tools/loop auto cand-NNNN-name --agent <your-name>
# update candidates/QUEUE.md; git commit with a `loop:` message
```

## Law spine

The site laws live in `sites/premath/specs/` (PREMATH-0000..0003: site,
gate/sheaf conditions, bidirectional descent, doctrine/tower). The landed
statements the kernel carries are in `sites/premath/statements/`:
`record-judgments-v0` (RJ-1.1..1.6, the record types), `queue-judgments-v0`
(QJ-1.1..1.5, the queue types), and `loop-model-v0` (LM-1.1..1.5, the
metacircular compared model and its coherence differential).

## Reproducibility

The flake at the repo root pins the toolchain (`nix develop`). An instance's
loop conformance is witnessed by the loop-model differential (below); a born
instance's birth witness is `EXPORT-RECEIPT.md`.

## KB, OKF, And Receipt-Memory Routing

Use this section when a request mentions KB, OKF, semantic envelopes,
receipt-memory projection, memory recall, source dialects, source adapters,
checked carriers, projection exits, source artifacts, evidence objects, support
witnesses, frontiers, or gluing Boat receipts into a knowledge surface.

Placement:

- Retained Fish KB material is source/provenance, not active current-cycle
  authority. Boat owns only the KB surfaces that have landed as governed seed
  material with `LANDING` destinations under `sites/kb`; broader KB meaning
  must be re-admitted before it is current-cycle authority.
- Boat owns only its governed records: candidates, decisions, briefs,
  attestations, landings, rollbacks, and memory-chain records.
- Harbor owns Harbor residency, readiness, publication, launch, live-smoke,
  and provider-operation meaning.
- The Boat skill may route projection work into Boat candidate seeds whose
  `LANDING` destinations are under `sites/kb`, but that projection is not a
  replacement authority chart.

Operational rule:

```text
receipt exists != claim is supported
claim supported != claim is admitted
memory recall != KB authority
Boat landing != Harbor readiness
```

### RLM Trace, Tusk Carriage, And OKF State

Use this split when work mentions RLM traces, trace-supported proposals,
Tusk lane receipts, checked carriers, OKF lowering, or export promotion:

- Boat/EVAL owns the RLM trace profile and checker when they have landed as
  governed source-local EVAL material. A passing RLM profile result is evidence
  with visible frontiers; it is not answer authority, KB admission, Boat
  candidate admission, Harbor readiness, or a live/provider claim.
- Tusk may carry stable RLM trace refs as lane or worker receipt evidence. That
  carriage is reference-only: it does not validate RLM semantics, redefine the
  profile, grant Boat admission, or turn Tusk into the owner of Boat/EVAL
  evidence.
- OKF remains one projection exit from a checked carrier packet. The carrier
  checker is the boundary before lowering; OKF output does not bypass support
  witnesses, visible frontiers, or the non-authority list.
- Source-local RLM/OKF helpers and reports are not export-kernel promises. A
  future promotion must first land exact export-manifest coverage, then update
  this skill only with manifest-covered citations, and must preserve the same
  authority boundaries.

The coherent path is:

```text
RLM trace evidence -> projection descent packet -> checked carrier refs
  -> Tusk reference-only carriage or OKF projection exit
```

Each arrow preserves source, evidence, support, lifecycle, frontier, and export
intent. Missing support, hidden context, stale integrity, lossy summary, or an
authority-boundary shift blocks the projection instead of being summarized
away.

Projection compiler discipline:

- A `source dialect` is the native record language of a source before
  normalization. Boat's first concrete dialect is its candidate, landing,
  attestation, review, trace, and memory-chain receipts.
- A `source adapter` is directional. Boat adapter v0 may read Boat receipts
  and emit normalized rows; it is not the compiler's universal input type and
  must not make other sources Boat-shaped.
- The reusable object is a checked carrier: source, evidence, support,
  lifecycle, frontier, and export-intent rows before any target format.
- The checker is part of the compiler boundary. Missing support, hidden
  admission, stale digest, lossy summary, or authority-boundary shifts block
  projection before lowering.
- OKF is one projection exit from a checked carrier packet, not the carrier,
  the source of authority, or the KB admission gate. Other exits may include
  static indexes, prompt packets, or later admission-evidence inputs, but they
  inherit the same non-authority list.

For projection-only work, land explicit source, evidence, support, lifecycle,
and frontier envelopes. The evidence should preserve the path:

```text
source artifact -> evidence object -> support witness -> visible frontier
```

For executable work, the first real rung is a checker, importer, source
adapter, or carrier that validates the profile and rejects hidden authority
shifts. If that work defines KB meaning, land the selected current-cycle KB
surface through Boat seeds with a `LANDING` destination under `sites/kb`, or
cite an explicitly active upstream owner that has been re-established by
placement; do not treat retained Fish paths as active authority. If it changes
Boat admission, landing, attestation, or export-kernel behavior, keep it in
Boat and use the normal loop. If it claims Harbor readiness or live
publication state, require a Harbor-owned receipt rather than projecting from
Boat memory alone.

Minimum frontiers for receipt-memory projection are:

- `admission_absent` when no KB admission event exists;
- `integrity_unverified` when a digest, signature, or memory-chain verifier
  was not run;
- `authority_boundary` when a source receipt is narrower than the projected
  claim;
- `lossy_summary` when raw traces, private material, or review-relevant source
  fields are omitted.

## The Pi surface (constraints that become interfaces)

Every gate below is a Pi-law: a universally quantified constraint over
candidates (`premath.record-judgments.v0`, adjoint reading). Before
discharge it blocks; once discharged it UNLOCKS an interaction. Sigma
builds (your seed material + witness packets accrete the store); Pi verifies;
your session is the transport between them — checking mode, always
(BIDIR-4.4). Every row below names a tool the export kernel carries, so the
table is accurate wherever this skill runs (`tools/skill-kernel-check.sh`
enforces exactly that).

| Pi constraint | Discharge check | Typed failure classes | Unlocked interface |
|---|---|---|---|
| Candidate record formation: META telescope + DECLARATION complete, vocabularies in-registry (DOCT-4.1/8.1, RJ-1.1/1.5) | `bash tools/loop validate ID` | `record-formation-incomplete`, `vocabulary-atom-failure` | status `open -> validated`; evaluation becomes meaningful |
| Evidence is a Sigma packet: verdict body + attestation witness (RJ-1.2) | `eval-self.sh` ends with `bash tools/eval/attest.sh write scores.json eval-self.sh traces`; reviewers re-run via `bash tools/eval/eval-check.sh CAND_DIR ROOT` (never eval-self.sh directly — it clobbers attestation) | `sigma-missing-witness`; `loop auto` refuses MALFORMED-JSON and non-`pass` | the brief can carry the evidence; auto becomes reachable |
| Decision binding: brief current, hash-acked | `bash tools/loop brief ID` | stale-brief refusal at land | admit / `loop auto ID --agent NAME` |
| Independent review (tier guard: any `LANDING` destination under `tools/` or `sites/premath/`) | `bash tools/loop review ID` — headless callers get printed Claude (`claude -p`) and/or Codex (`codex exec`) convening recipes when available; AT MOST 2 transform rounds (DOCT-9.4, CONTROLLING); a round-2 impasse goes to the QUEUE unlanded, which is success | reviewer `transform`/`deny` | `loop land` with git snapshot |
| Landing lineage: LANDED manifest + real snapshot + agent-labeled DECISION (ROUTE-1.2: worker self-report never counts) | `bash tools/loop auto ID --agent NAME` | dispatch refuses unverified landing claims | `loop rollback ID` stays available; record/reflect run |
| Deterministic failure identity (`premath.core.witness-id.v0`) | `printf '{"class":"C","lawRef":"L","tokenPath":null,"context":null}' \| bash tools/eval/witness-id.sh`; vectors: `--self-test` | exit-65 fail-closed family (unknown field incl. `message`, floats, malformed) | any consumer can cite a failure by stable `w1_` ID |
| Loop coherence: the bash loop and its metacircular model agree (LM-1.2 agreement projection) | `bash tools/loop-model-diff.sh --fixtures` (suite member); `--store` sweeps the whole candidate store | `model_coherence_failure` (GATE-3.5 shaped) | the GATE-3.5 coherence evidence; the instance's conformance witness |
| Post-land conformance (the live suite, all conditional) | `bash tools/eval/evaluate-landed.sh CAND_DIR` — runs the present members (cross-surface, queue-judgments, verdict-tripwire, loop-model, and any others on the source) over the landed tree | per-member FAIL | the landing is witnessed conformant after the fact |

## Using boat as the tool for a project

Project work enters as candidates like everything else: seed material may land
anywhere the `LANDING` map declares (keeping the destination under
`sites/<name>/` keeps it inside the governed tree); `candidates/QUEUE.md` is
the backlog;
`bash tools/loop dispatch --agent NAME --goal G --max-attempts N
--budget-usd X` runs one bounded worker iteration, and outcomes are verified
against the store, never against worker self-report. The project's artifacts
are checking-mode inputs until discharged — what survives the Pi surface
above is what the project IS. To grow the project its OWN law: land a
statement under `sites/<project>/`, a checker into `tools/`, and enroll the
checker in `tools/eval/evaluate-landed.sh` — from then on every later
candidate must satisfy it.
