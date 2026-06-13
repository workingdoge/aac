# cand-0005-lit-components

Intent: The AAC design system as **Lit web components** — `aac-record` (a
journal voucher), `aac-stamp` (status), `aac-proof` (the invariant proof
terminal) — themed by the verified design tokens and shown on a `/components`
page in the site.

Status: open (pre-threshold).

## Cargo (9 files)

- `web/src/components/{aac-record,aac-stamp,aac-proof,elements}.ts` — Lit custom
  elements. Registered directly via `customElements.define` (no decorators —
  Vite/esbuild does not transpile them).
- `web/src/components/Loader.astro` — a hoisted `<script>` that bundles + loads
  the element registrations (an MDX `<script>` is dropped by Astro).
- `web/src/content/docs/components.mdx` — the showcase page.
- `web/{package.json,bun.lock}` — add `lit`; `web/astro.config.mjs` — the
  Components nav entry. (Replace cand-0004's versions.)

The components are themed entirely through the `--aac-*` CSS custom properties
(which inherit into shadow DOM), so they track the design tokens. The proof
terminal is a fixed dark surface — proofs are invariant.

## Declaration

`layer: artifact`. `preserves: none` — net-new components.

## Tier

Not tier-sensitive: lands under `web/` (project artifact).

## Evaluation

`eval-self.sh`:

- all three elements register: `customElements.define('aac-record'|'aac-stamp'|'aac-proof', …)` present in source.
- token-themed: the components reference the `--aac-*` custom properties.
- `lit` is a declared dependency.
- the site builds: if `web/node_modules` is present, `astro build` succeeds
  (14 pages) and the bundled JS carries the `aac-*` registrations; skipped
  honestly if deps/paint absent.
