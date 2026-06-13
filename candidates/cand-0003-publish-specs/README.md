# cand-0003-publish-specs

Intent: Publish the AAC RFC suite as a **verified Paintgun spec-publication
pack** — an `atlas.spec-publication.v1` manifest over `sites/ledger/specs`
(11 documents), built and verified by `paint spec-pack` / `verify-spec-pack`.
Even the spec publication is an attested pack.

Status: open (pre-threshold).

## Cargo

1 file:

- `sites/ledger/publication.json` — the `atlas.spec-publication.v1` manifest.
  `site: aac`, `sourceRoot: specs` (resolved relative to the manifest's own
  directory — paintgun enforces that dir as a trust root, no `..`/symlink
  escape). Two series: `rfc` (the catalog index + PACI…OTC, the 9 numbered
  specs) and `registers` (R1). Each document carries `id`, `title`, `status`
  (Raw), `category`, `path`, `order`.

## Build

From `sites/ledger/` (or anywhere — paths are manifest-relative;
`nix develop` provides `paint`):

```sh
paint spec-pack sites/ledger/publication.json --out dist-spec
paint verify-spec-pack dist-spec/spec.pack.json --format json   # ok:true ⟺ pack re-verifies
```

Emits `dist-spec/spec.pack.json` + `spec.index.json` + copied `sources/` — a
self-contained, content-addressed publication pack. `dist-spec/` is
regenerable and gitignored. This pack is what cand-0004's Astro + Starlight
site syncs its `src/content/docs` from.

## Declaration

`layer: artifact` — publication metadata for the ledger site's specs.
`preserves: none` — net-new authored manifest.

## Tier

Not tier-sensitive: lands at `sites/ledger/publication.json` (the ledger
project site, not the law spine `sites/premath/` or `tools/`).

## Evaluation

`eval-self.sh` exercises the pack in a scratch copy (the trust root), real-JSON
parse (not a grep):

- `paint spec-pack` succeeds against a real copy of `sites/ledger/specs`.
- `paint verify-spec-pack` returns `ok:true` with `checkedDocuments == 11`.
- completeness: every declared document (`index`, `PACI`…`OTC`, `R1`) is
  present in `spec.pack.json` with its source copied.
- rejection: a manifest whose document path points at a missing file makes
  `spec-pack` fail (no silent pass over a broken publication).

Located via `PAINT_BIN`/`PATH`; honest-skip (exit 75, attested) if absent.
Closes by attesting `scores.json` via `tools/eval/attest.sh`.
