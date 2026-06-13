# cand-0007-circuit-ux

Surfaces the landed TRANSITION/1 circuit ([cand-0006](../cand-0006-noir-transition))
in the AAC site. Adds a **`/circuit`** page and an **`aac-transition`** Lit web
component that renders the real proven public-input ABI vector (3/PROOF S4.1) as
a proof receipt — prev->next account and nullifier roots, the recomputed
`journal_commitment` / `fact_fold`, the `unconstrained` `context_commitment`,
and the constraints the circuit discharged — in the invariant dark proof
surface. The page ties the soundness story to `journal_sum_field_sound`
(Core.lean) and gives the `nargo` run commands.

The displayed values are the actual public inputs `nargo execute` solved for the
`circuits/transition` sample.

## Evidence (`eval-self.sh`, attested)

- register — `aac-transition` calls `customElements.define`, imported by `elements.ts`.
- theme — themed via `--aac-*` tokens (inherit through shadow DOM).
- page — `/circuit` embeds `<aac-transition>`, names TRANSITION/1, ties to
  `journal_sum_field_sound`, linked in the sidebar.
- build — `astro build` green; `/circuit` built with the element bundled.

Status: open (pre-threshold).
