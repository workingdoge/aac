# AAC design standard — American Accounting Company

The design system source: a [paintgun](https://github.com/workingdoge/paintgun)
DTCG 2025.10 token pack, build- and verify-clean, feeding the spec site and the
Lit component library. The JSON here is the **source of truth**; the CSS is a
generated, regenerable lowering (gitignored).

> **American Accounting Company** — *instruments for network capital.*
> Signed records for real commerce. The ledger is the institution. Proof-of-commerce.

The aesthetic is an **instrument**, not an interface. The core object is a
**record** — a sealed journal voucher — not a card. Status is **stamped, not
badged**. Light mode should read "old enough to be trusted."

## Recorded colors (canonical)

These are **invariants** — a design standard states its pigments; it does not
re-theme them. The canonical value is the printed (light) value.

| Token | Hex | Role |
|-------|-----|------|
| `cream` | `#F1EAD7` | ledger paper — forms, receipts |
| `bond` | `#FAF5E9` | lighter paper — the record surface |
| `ink` | `#17140F` | black ink — authority, finality, the framing rule |
| `ink2` | `#3A352C` | body |
| `navy` | `#1C2A4A` | federal navy — institutional trust, links |
| `oxblood` | `#7E2A22` | seal red — attestation, exception (dried ink, never coral) |
| `steel` | `#5E636B` | infrastructure, neutrality |
| `gold` | `#97793C` | custody, reserves — used sparingly |
| `rule` / `rule2` | `#D8CDB2` / `#BCAF8C` | hairlines |

Terminal / proof surface (constant): `paperOnInk #EDE7D6`, `verified #7FB08A`,
`goldLit #C9A85C`, `dim #8C8678`.

## Two schemes — paper becomes ink

The `dark` scheme inverts the instrument: `cream` drops to a warm near-black
ground (`#15120D`) and `ink` lifts to parchment (`#F0E9D8`), so the
high-contrast ink line that frames every record stays the structural constant.
Accents lift just enough to stay legible — `navy #93A9CE`, `gold #C6A45A` — and
**`oxblood` holds as a deep brick `#AD4A33`** (never coral; coral reads casual,
and the seal is dried-ink authority).

## Three hands

- `font.serif` / `font.display` — **Libre Caslon** Text + Display: identity and
  documents, early-American printing gravitas.
- `font.sans` — **Public Sans**: the product interface, the US federal face.
- `font.mono` — **IBM Plex Mono**: anything with evidentiary value — proofs,
  hashes, receipts, journal entries.

Weights `400 / 500 / 600 / 700`; a `text` scale from `micro` (10px) to `xxxl`
(46px); a `space` scale `s1…s9` (4→88px); `radius.r` 2px.

## Invariants worth stating

- **The proof terminal is identical in both schemes.** Proofs are invariant —
  making the proof surface constant says so visually.
- **The seal hits clear paper** — a stamp never lands on live text. A binding
  layout rule for the `aac-seal` / `aac-record` components.
- **Status is stamped:** `status.recorded` (navy), `reconciled` (gold),
  `sealed` (oxblood), `pending` (steel), `exception` (oxblood).

## Build

From the repo root (`nix develop` provides `paint`):

```sh
cd design
paint build ./aac.resolver.json --contracts ./component-contracts.json \
  --target web-css-vars --namespace aac --out dist
paint verify dist/ctc.manifest.json --format json   # ok:true ⟺ the lowering re-verifies
```

`paint build` emits `dist/tokens.css` (`:root[data-scheme="light"|"dark"]`
custom properties), `components.css` (the contract bindings), `tokens.d.ts`,
and the CTC manifest + witnesses. `dist/` is regenerable and gitignored.
