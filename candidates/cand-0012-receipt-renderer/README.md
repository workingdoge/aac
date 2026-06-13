# cand-0012-receipt-renderer

The `aac-receipt` Lit web component — a **BalancedVectorReceipt** rendered
(Design Note 0001 / EVENT-COMPLETE/1). It shows the buyer/supplier event from
the shipped Pⁿ conformance vector as a multi-dimensional journal: columns
`USD · fabric · garment`, debit and credit totals **equal per dimension**
(`✓ ✓ ✓`), role coverage (Buyer/Supplier), and proof/nullifier status — the
incommensurability thesis made visible (nothing collapses through price). Shown
in a new "The receipt" section of `/components`.

Verified live in the preview: the element upgrades and renders the per-dimension
balance (Total Dr = Total Cr = `100.00 / 50 / —`), role stamps, and the
"P³ zero-account ✓ · no numeraire" footer, with no console errors.

## Evidence (`eval-self.sh`, attested)

- register — `aac-receipt` calls `customElements.define`, imported by `elements.ts`.
- theme — themed via `--aac-*`; states the no-numeraire thesis.
- page — `/components` embeds `<aac-receipt>` and names the BalancedVectorReceipt.
- build — `astro build` green; the receipt is built into `/components` and bundled.

Status: open (pre-threshold).
