# cand-0090-lineage-reconciliation-record

Intent: Record the 2026-07-03 dual-lineage reconciliation (irai-227): merge, queue union, chain repair, kernel restoration

Status: open (pre-threshold).

## Declaration Rationale

Layer: `evidence-tooling`. This candidate changes no ledger doctrine,
specification, circuit, runtime, or kernel behavior. It records the evidence
state of the 2026-07-03 reconciliation, preserves the reconciled queue shape
through a candidate-local seed, and attests the checks that make the record
reproducible.

`preserves` uses `dm.refine.context` for the lineage context refinement and
`dm.commitment.attest` for the evidence record and evaluator witness.

## Cargo

- `seeds/sites/ledger/design/0005-lineage-reconciliation-record.md` ->
  `sites/ledger/design/0005-lineage-reconciliation-record.md`
- `seeds/sites/ledger/design/README.md` ->
  `sites/ledger/design/README.md`
- `seeds/candidates/QUEUE.md` -> `candidates/QUEUE.md`

The seeded queue adds three open follow-ups and a resolved entry for this
record. It preserves exactly one `## Open` and one `## Resolved` header.

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
