# AAC design standard — American Accounting Company

The design system source: a [paintgun](https://github.com/workingdoge/paintgun)
DTCG 2025.10 token pack, build- and verify-clean, feeding the spec site
(`web/`) and the components. The JSON here is the **source of truth**; the CSS
is a generated, regenerable lowering (gitignored).

> **American Accounting Company** — *instruments for network capital.*
> Records that balance, trust that endures. Precision · integrity · persistence.

The identity is **Swiss-modernist**: a geometric mark, letterspaced grotesk,
two colours, hairline rules. Restrained — the white OCBD.

## The mark

A **ledger cell** — `AAC` in a navy ring, framed by red brackets (`|` left/right)
and red rules (top/bottom): a bracketed double-entry cell. `design/brand/aac-mark.svg`
(also `web/public/{favicon,logo}.svg`).

## Recorded colours

Two colours carry the brand; ink + cream are the ground. (Canonical = light;
these are invariants.)

| Token | Hex | Role |
|-------|-----|------|
| `navy` | `#21324F` | primary — the mark, headings, links, the CTA |
| `oxblood` | `#93302C` | the rule — accents, the single red line |
| `ink` | `#1A1A1A` | body text |
| `cream` | `#F8F3E7` | page ground |
| `bond` | `#FFFFFF` | raised surface |
| `steel` | `#6B6B64` | muted |
| `rule` / `rule2` | `#E2DAC4` / `#C9BE9E` | hairlines |

(`gold #B08A4B` remains a token but is used sparingly / not in the mark — fewer
colours.) A `dark` scheme inverts ground ↔ ink with lifted accents.

## Type

**Neue Haas Grotesk** (licensed), letterspaced — **Inter** is the free web
substitute (`web/`). `IBM Plex Mono` for anything evidentiary (hashes, proofs,
receipts). Weights 400 / 500 / 600 / 700; a `text` scale `micro`→`xxxl`; a
`space` scale `s1`→`s9`; `radius.r` 2px.

> Gotcha: paintgun's `web-css-vars` double-quotes `fontFamily` token values,
> so the site sets its font stacks literally in CSS rather than via the
> `--aac-font-*` vars. Colours come through the tokens clean.

## Build

From the repo root (`nix develop` provides `paint`):

```sh
cd design
paint build ./aac.resolver.json --contracts ./component-contracts.json \
  --target web-css-vars --namespace aac --out dist
paint verify dist/ctc.manifest.json --format json   # ok:true ⟺ re-verifies
```

`dist/` is regenerable and gitignored. The site regenerates `tokens.css` from
these on every build (`web/scripts/sync-specs.mjs`).
