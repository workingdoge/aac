# cand-0004-modernist-identity-site

Intent: Pivot the AAC identity and site to the **Swiss-modernist** direction
(the user's brand board): retone the design tokens to the two-colour navy/red
palette + Inter, the **ledger-cell mark**, and a fresh Astro + Starlight site
that renders the verified spec pack in the new livery.

Status: open (pre-threshold).

## Cargo (16 files)

- `design/tokens/*` — retoned to the modernist palette (navy `#21324F`, red
  `#93302C`, ink `#1A1A1A`, cream `#F8F3E7`) + Inter; **replaces** cand-0002's values.
- `design/brand/aac-mark.svg` + `design/README.md` — the cell mark + the updated standard.
- `web/**` (source only — `node_modules`, `dist`, `.astro`, `.generated`, the
  generated `tokens.css` and `content/docs/specs/` are gitignored): the Astro +
  Starlight app, `sync-specs.mjs` (consumes the paintgun spec pack), the theme
  CSS, the masthead, the favicon/logo.

## Declaration

`layer: artifact`. `preserves: none` — a deliberate re-tone, not a preservation
(supersedes the Caslon direction).

## Tier

Not tier-sensitive: lands under `design/` and `web/` (project artifacts, not
`tools/` or the `sites/premath/` law spine).

## Evaluation

`eval-self.sh`, real checks (paint located via PAINT_BIN/PATH; honest-skips):

- tokens build + verify clean (`paint build` / `verify`, ok:true).
- the spec pack still publishes (`paint spec-pack` + `verify-spec-pack`, ok:true).
- the mark is two-colour: favicon/logo carry navy + red and **no gold**
  (`#b08a4b` absent) — the "fewer colours" witness.
- the web scaffold is valid: `package.json` parses with astro + Starlight; the
  config, sync script, and theme are present.
- the site builds: if `web/node_modules` is present, `astro build` succeeds
  (13 pages); skipped honestly if deps are absent.
