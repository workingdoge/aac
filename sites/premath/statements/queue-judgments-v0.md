# Premath Queue Judgments v0

Statement id: `premath.queue-judgments.v0`
Owner: Premath (judgment theory: SigPi; record theory:
`premath.record-judgments.v0`)
Status: active for `boat-2026-05-17`

Provenance: boat-native synthesis over landed surfaces only — RJ-1.3/1.5/1.6
(`premath.record-judgments.v0`), BIDIR-4.4 (PREMATH-0002 §4),
`premath.regular-doctrine.v0` (atomic predicates). The edge/ready laws
(QJ-1.4) are the validated laws of the retained premath-bd issue
substrate (blackhole/fish-2026-05-16/sites/premath/crates/premath-bd),
ported as law-for-later WITHOUT its code (the crate was deleted by its
own cleanup lineage at e881de7 "reduce premath to admissibility core";
bulk runtime import refused per
imports/receipts/OBSTRUCTION-PREMATH-BULK-RUNTIME-IMPORT-2026-05-16.md);
and `WORK-TRACKER-CHECKER-PROFILE` Rule C4 (projection-never-authorizes).

## Purpose

candidates/QUEUE.md is the loop's proposal source, written by humans,
agents, and the loop's own reflect/escalation appenders, and read by
dispatch, board.sh, and unit-metrics.sh. It is free-form markdown typed
by nothing. This statement gives its entries their judgment, so the file
can be linted as a record surface — without migrating it to a store
(deferred; see Boundary).

This statement types the EXISTING file. It introduces names and a lint,
not a new substrate.

## Queue judgments

Law: QJ-1.1 — Entry formation. A queue entry is a term of the telescope

```text
status : QueueStatusVocab, origin : Origin, date : Date, body : Prose
```

with the surface grammar `- [status] (origin, date) body`, continuation
lines indented, terminated by the next `- [` entry or `## ` section.
QueueStatusVocab is a profile-owned atomic predicate (RJ-1.5): the v0
vocabulary is `open` and `resolved` (the resolved form may carry a
`resolved: cand-NNNN` tag inside the brackets). An entry whose status is
out of vocabulary, or whose grammar does not parse, fails formation with
class `vocabulary-atom-failure` (status) or `record-formation-incomplete`
(grammar).

Law: QJ-1.2 — Section discipline. `## Open` admits only `open` entries;
`## Resolved` admits only `resolved` entries. A `resolved` entry under
`## Open` (or an `open` entry under `## Resolved`) is a misfiling, class
`record-formation-incomplete` at tokenPath `QUEUE.section`. (Two such
misfilings exist on the live file at admission of this statement; the
lint surfaces them.)

Law: QJ-1.3 — Checking-mode consumption. Queue entries are untrusted
proposal artifacts (RJ-1.3 / BIDIR-4.4): a consumer compiles an entry's
claims to obligations before acting on it, and never treats entry text
as authored input. Unattended dispatch consumption is operator-gated by
origin (realized: `tools/schemas/dispatch-origins.allow`, cand-0041); a
consumer that interpolates entry text as an instruction without that gate
commits `verifier_contract_violation`.

Law: QJ-1.4 — Dependency and readiness (LAW-FOR-LATER; not realized in
v0). When queue entries carry dependency edges, the edge invariants are
exactly the retained bd laws: both endpoints exist, no self-loop, no
duplicate (from, to, kind) triple, and cycles are rejected with the
cycle path in the error; the edge-kind vocabulary is exactly
`blocks | discovered-from | supersedes` (the kinds carrying 99% of real
bd edges). Readiness is conservative: an entry is ready iff every
blocking edge points at a resolved entry, and a missing blocker keeps the
entry blocked. These laws are stated so the eventual realization (gated
on the protocol's revisit triggers: more than one concurrent dispatch
consumer, or a misdispatch a missing edge would have prevented) descends
a spec that already exists. v0 admits NO edges and NO ready computation.

Law: QJ-1.5 — Projection never authorizes (Rule C4). QUEUE.md is the
authored/appended surface; board.sh and unit-metrics.sh are projections
of it (dm.presentation.projection). A projection MAY change
representation but MUST NOT authorize a mutation of any record — no
consumer of the rendered or parsed queue may use its read as license to
write the store, the chain, or a landing. The canonical parser
(`tools/queue-lib.sh`) is a reader; it emits records, it never mutates.

## Boundary

This statement does not admit: a queue store, an event log, hash-chained
queue events, dependency edges, ready computation, or QUEUE.md as a
rendered-from-store projection (all DEFERRED; the file stays the
authored surface, and migrating it is gated on the protocol's R1 revisit
triggers). It does not admit a checker for QJ-1.4 (law-for-later). It
adds NO checking power beyond the lint described here: the same grammar
the loop's appenders already produce, now declared and checkable. Per
RJ-1.6 the statement is the type; QUEUE.md is a wire surface and
tools/queue-lib.sh / the .schema-style vocabularies are compiled
artifacts, never executable authority. No claim that the live file
already satisfies QJ-1.1/1.2 — the lint exists precisely because it does
not yet (two misfilings known at admission).
