# cand-0002-design-tokens

Intent: Lock the AAC design-token pack — the **American Accounting Company**
design standard (recorded colors, three hands, the measure) as a paint-verified
DTCG 2025.10 pack with light + dark ledger schemes; the source the spec site and
Lit components consume.

Status: open (pre-threshold).

## Cargo

6 files landing into a new top-level `design/` (the design-system source):

- `design/aac.resolver.json` — DTCG 2025.10 resolver: a scheme-independent
  `base` set + a `scheme` modifier with `light` and `dark` contexts.
- `design/component-contracts.json` — slot bindings for `aac-page`, `aac-record`,
  `aac-seal`, `aac-stamp` (the seam tokens → CSS → Lit).
- `design/tokens/aac.base.json` — three hands, weights, the type/space scale,
  radius, rule, measure (scheme-independent).
- `design/tokens/scheme/light.tokens.json` — the recorded pigments + terminal
  shades + `status.*`, light values.
- `design/tokens/scheme/dark.tokens.json` — the same, "paper becomes ink".
- `design/README.md` — the design standard (recorded colors, three hands,
  invariants, build).

See `LANDING` for the per-file map. The generated CSS (`paint build` output) is
regenerable and gitignored, never cargo — the cand-0040 (boat) precedent.

## Declaration

`layer: artifact` — design-system source. `preserves: none` — net-new authored
tokens (AAC is greenfield on brand; nothing prior in-repo is preserved).

## Tier

Not tier-sensitive: LANDING destinations are all under `design/` (a project
artifact tree, not the law spine `sites/premath/` or the verifier set `tools/`).

## Evaluation

`eval-self.sh` builds the pack with `paint` into a scratch dist and witnesses,
with a real JSON parse (not a grep):

- `paint build` succeeds and `paint verify` returns `ok:true` (verify.ok +
  semantics.ok) — the CTC envelope re-verifies the lowering.
- both `:root[data-scheme="light"|"dark"]` blocks emit; every expected
  `--aac-color-*` recorded pigment + `status.*` present in both; no empty values.
- the two schemes differ (paper-becomes-ink): `bg` and `ink` differ light vs dark.
- content cross-check: the canonical light hexes match the standard
  (`cream #f1ead7`, `ink #17140f`, `navy #1c2a4a`, `oxblood #7e2a22`), and the
  **dark oxblood is the brick `#ad4a33`, not coral** — the agreed fix, machine-checked.
- corrupted-input rejection: a truncated token source makes the build fail.

Located via `PAINT_BIN`/`PATH`; honest-skip (exit 75, attested) if `paint` is
absent. Closes by attesting `scores.json` via `tools/eval/attest.sh`.

## Follow-on

cand-0003 `paint spec-pack` over `sites/ledger/specs`; cand-0004 the Astro +
Starlight site consuming the generated CSS; cand-0005 the Lit component library
(`aac-record`, `aac-seal`, `aac-stamp`, the proof terminal). The seal-hits-clear-
paper rule is a binding layout invariant for cand-0005.
