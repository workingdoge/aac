# cand-0020-registry-ux

Surfaces the on-chain **4/REG** registry in the site — the demo-facing payoff that
makes the whole proof→chain pipeline visible. Adds a **`/registry`** page and an
**`aac-row`** Lit component rendering a registry Row advancing from a TRANSITION/1
proof: the **real** roots (`account_root` / `nullifier_root`) prev→next, the
nonce 0→1, the verifier-contract discharge checklist (3/PROOF §5: proof verified
on-chain · old-root equality · context pinned), and the `Updated` event — with
"the registry refuses anything it cannot verify."

The page states the 4/REG update rule and the pipeline (`bb prove --oracle_hash
keccak → HonkVerifier → Registry.update`), tying it to [/circuit](/circuit/).

Verified live in the preview: the element upgrades, the row shows the real
prev→next roots + nonce bump + discharge + event, no console errors.

## Evidence (`eval-self.sh`, attested)

- register — `aac-row` calls `customElements.define`, imported by `elements.ts`.
- theme — themed via `--aac-*`; states the refusal/old-root trust model.
- page — `/registry` embeds `<aac-row>`, names 4/REG + the update rule, sidebar-linked.
- build — `astro build` green; `/registry` built with the element bundled.

Status: open (pre-threshold).
