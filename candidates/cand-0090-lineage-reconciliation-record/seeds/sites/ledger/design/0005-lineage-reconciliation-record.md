# Design Note 0005 - Dual-Lineage Reconciliation Record

- Status: **non-normative reconciliation record** (NOT an RFC; changes no
  ledger semantics)
- Editor: governed build worker for `cand-0090-lineage-reconciliation-record`
- Touches: candidate store lineage, `candidates/QUEUE.md`, `memory/log.jsonl`,
  and the Boat export kernel in this `aac` instance
- Provenance: records the operator-authorized 2026-07-03 reconciliation for
  workspace tracker `irai-227`

> **One line.** The 2026-07-03 reconciliation joined two governed-loop
> lineages that forked at `713248d`, preserved both landed histories, repaired
> the memory chain without textual hash-chain merging, and restored the Boat
> kernel to the refreshed typical fibre.

## 1. Fork Point And Lineages

The common fork point is `713248d`, the 2026-06-13 close-out for
`cand-0036-naming-layering`.

The local lineage is preserved at `backup/pre-reconcile-019a76e`, whose tip is
`019a76e`. From `713248d` to `019a76e`, that lineage landed:

- `cand-0037-event-harness`
- `cand-0038-provekit-beta19`
- `cand-0039-second-posting-program`
- `cand-0040-repo-clearing`
- `cand-0041-clearing-novation-note`
- `cand-0042-novate`
- `cand-0043-ust-trade`
- `cand-0044-pedersen-vector-profile`

It also added `atlas.site.json` and two stopgap `port:` commits,
`75bcb5a` and `5ab2cb8`, copying ProveKit and fundraising/BCC material from
`codex/vnet-fundraising`.

The remote lineage is `origin/main@dc92348`. From the same fork point it
landed a different `cand-0037..cand-0089` program, including the
vnet-fundraising/BCC/LEDGER sequence, the canonical merge of
`codex/vnet-fundraising`, and the web deployment surface for `www.aac.sh`.

## 2. Reconciliation Commits

The visible reconciliation path is:

- `07b1f8f` committed untracked operator material before reconciliation:
  `brand/`, `circuits/architecture.html`, and
  `candidates/cand-0029-queue-archive`.
- `2776e4a` merged `origin/main`.
- `396876c` repaired `memory/log.jsonl` after the merge by re-importing local
  loop landings.
- `f61dbd6` refreshed the kernel from loop commit `a48ed2e` and committed
  `REFRESH-RECEIPT.md`.

## 3. Candidate Number Collision

Both lineages contain landed candidates numbered `cand-0037` through
`cand-0044`, but the slugs differ. For example,
`cand-0037-event-harness` is local lineage material and
`cand-0037-vnet-profile-vectors` is remote lineage material.

No renumbering was performed. Renumbering landed candidates would falsify the
landing records and the memory-chain evidence that names them. Numbering
uniqueness holds by `(number, slug)` pair for the collision era; number-only
references into `cand-0037..cand-0044` are ambiguous and must cite the slug.

Future candidates continue from `cand-0090`.

## 4. Conflict Policy

The verified remote-wins policy is narrower than the informal summary. The
merge result at `2776e4a` is byte-identical to `origin/main@dc92348` for these
overlap paths:

- `fundraise-demo-runner/README.md`
- `fundraise-demo-runner/bin/fundraise-demo.mjs`
- `fundraise-demo-runner/package.json`
- `fundraise-demo-runner/src/index.d.ts`
- `fundraise-demo-runner/src/index.mjs`
- `fundraise-demo-runner/test/run-tests.mjs`
- `fundraise-runtime/src/index.d.ts`
- `fundraise-runtime/src/index.mjs`
- `fundraise-runtime/test/run-tests.mjs`
- `memory/log.jsonl`
- `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`

Those local variants were stopgap ports of the same source branch and remain
recoverable at `backup/pre-reconcile-019a76e`.

`candidates/QUEUE.md` was hand-unioned. A second verified exception is
`sites/ledger/specs/applications/README.md`: it was also hand-unioned, keeping
remote's `LEDGER/1` application-surface language and local `NOVATE/1`.

## 5. Queue Union

Before this candidate, the live queue had exactly one `## Open` header, one
`## Resolved` header, 21 open entries, and 86 resolved entries, and
`tools/queue-lint.sh candidates/QUEUE.md` reported clean.

The queue used the remote queue as its base. The `Kernel/app decouple` entry
took the local variant because the local lineage factored the EVENT/BVR
harness in `cand-0037-event-harness`, a step the remote lineage did not take.
Three local-only open entries were appended:

- `Second posting program`
- `VNET/1 reference circuit`
- `ProveKit nix-repro via the co-snarks pattern`

The `VNET/1 reference circuit` and `ProveKit nix-repro` entries may already be
partly or fully superseded by remote landings such as
`cand-0052-provekit-vnet-circuit` and `cand-0050-provekit-flake-import`; that
is queue hygiene work, not a reconciliation rewrite.

## 6. Memory Chain Repair

The merge commit `2776e4a` kept the remote `memory/log.jsonl` chain
wholesale. The hash of `memory/log.jsonl` at `2776e4a` matches
`origin/main@dc92348`, so no textual merge was introduced into the
hash-chained log.

Commit `396876c` then ran the loop-memory import path to re-derive the eight
local-only landing records from the preserved candidate directories. After
that repair, `bash tools/memory.sh verify` reports `memory: verify ok (96
records)`.

## 7. Kernel Restoration

`REFRESH-RECEIPT.md` records a `boat.refresh.v0` refresh on 2026-07-03 from
`/Users/arj/irai/loop` commit `a48ed2e`. It reports 19 updated files, 158
identical files, and 10 restored-from-skew files:

- `WORKER.md`
- `.agents/skills/boat/SKILL.md`
- `tools/loop`
- `tools/queue-lint.sh`
- `tools/route.sh`
- `tools/eval/attest.sh`
- `tools/eval/evaluate-candidate.sh`
- `tools/eval/evaluate-landed.sh`
- `tools/eval/witness-id.sh`
- `tools/schemas/export-manifest.tsv`

Both pre-reconciliation lineages left those 10 paths unchanged after the fork.
The refresh commit `f61dbd6` is the commit that changed them.

No `tools/schemas/kernel-adaptations.tsv` exists in this instance. The instance
identity remains `cycle_id aac-2026-06-13` and `instance aac` in
`tools/schemas/instance.tsv`; this is a soul carve-out rather than an
adaptation.

The local evidence for conformance is the committed `REFRESH-RECEIPT.md` and
`.boat-refresh-conformance.log`, where the loop-model fixture differential
reports zero disagreements. The informal claim that
`boat-refresh --wave --check` reports `aac 187/187 identical` is not
reproducible from this tree alone: `bash tools/loop boat-refresh --wave --check`
is not a `tools/loop` command, and `bash tools/boat-refresh.sh --wave --check`
exits 66 because `tools/schemas/bundle-base.tsv` is absent.

## 8. Follow-Ups

This record names, but does not perform, three follow-ups:

- Atlas registry mirror re-pin: the operator note says Atlas pins
  `019a76ef`, while this repository's HEAD has moved to `f61dbd6`. The pin
  itself is not represented in this `aac` tree and needs the Atlas registry
  mirror.
- Push decision for origin: local `main` is ahead of `origin/main`; pushing is
  operator-held.
- Staleness triage of the three re-appended local queue entries:
  `ProveKit nix-repro`, `Second posting program`, and `VNET/1 reference
  circuit`, especially against remote `cand-0037..cand-0060` landings.

## 9. Boundary

This record does not push, land, admit, review, commit, renumber candidates, or
modify `backup/pre-reconcile-019a76e`. It records what the reconciled tree
already shows and queues the remaining operator or hygiene work.
