# cand-0013-phi-rulebook

A **Φ_R event-to-journal compiler** for the goods-receipt-invoice schema, landed
as the `circuits/rulebook` lib crate (depends on `pacioli`). This is the
"fraud can balance" fix in running code: `compile_goods_receipt_invoice(event)`
deterministically **emits** the vector journal, so the journal is the schema's
image — not arbitrary balanced entries.

Realizes EVENT-COMPLETE/1 obligations 4 (canonical compilation `J = Φ_R(E,q,…)`)
and 5 (Pⁿ zero-account) for one schema. Two properties proven:

- `phi_reproduces_the_conformance_vector` — `compile({usd:100.00, fabric:50m})`
  equals the exact journal the `pacioli` Pⁿ conformance vector (cand-0009)
  hard-codes. The journal is **derived**, not asserted.
- `phi_is_balanced_for_all_quantities` — the schema compiles to a zero-account
  for *any* quantities (5 cases incl. 2⁶⁴−1): each quantity is posted once Dr
  and once Cr, so balance is a **theorem of the schema**, not a check on inputs.

## Evidence (`eval-self.sh`, attested)

- derives — the compiler + both Φ_R tests are present, reproduce the conformance
  journal, cite EVENT-COMPLETE/1, and the workspace lists the new crate.
- test — `nargo test` green on `rulebook` (built against the landed `pacioli`),
  and the whole workspace still compiles with the crate added.

Status: open (pre-threshold).
