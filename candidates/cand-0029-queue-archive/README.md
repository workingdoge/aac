# cand-0029-queue-archive

Intent: bound aac's queue as working memory. Ship `tools/queue-archive.sh`
(boat kernel hygiene, cand-0053/0054) so resolved entries can be archived out of
the working queue and the open backlog warns past a soft bound. aac already
carries the only dependency (`tools/queue-lib.sh`, the canonical parser).

## Cargo (verbatim from the boat kernel, ROOT-relative)

- `queue-archive.sh` → `tools/queue-archive.sh`: two subcommands. `archive
  [QUEUE] [ARCHIVE]` moves every RESOLVED-status entry verbatim to
  `candidates/QUEUE-archive.md` — content-preserving (open entries + preamble
  byte-untouched), idempotent, and self-checking (line-multiset conservation =
  no line ever lost; refuse-rather-than-fragment on a column-0 `## ` inside a
  resolved body). `check [QUEUE]` reports the open count and WARNS over
  `QUEUE_OPEN_BOUND` (default 40) — advisory only, exit 0 always. The candidate
  STORE is never touched (immutable evidence).
- `export-manifest.tsv` → `tools/schemas/export-manifest.tsv`: **+1, -0** (built
  from the post-cand-0028 base, so the record-judgments +9 is preserved), so the
  tool travels if aac ever births a sub-instance.

## Evaluation (eval-self.sh, attested)

t01 manifest grammar intact, the new entry is provided by the LANDING map
(post-land honest), and the `queue-lib.sh` dependency is present in aac; t02
`check` runs on aac's live queue (read-only) and exits 0; t03 archive
content-preservation on a synthetic queue — every resolved entry moves to the
archive, every open entry and the preamble stay byte-untouched, the line
multiset is conserved (no data loss), both files lint-clean, and a rerun is a
byte-exact no-op (idempotent); t04 deltas additive (manifest -0/+1, `tools/loop`
untouched).

## Tier

LANDING touches `tools/` (the tool + `tools/schemas/export-manifest.tsv`) — an
independent REVIEW.md is required.
