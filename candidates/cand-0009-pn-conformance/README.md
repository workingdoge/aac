# cand-0009-pn-conformance

Bakes the Pⁿ incommensurability thesis into the shipped test suite
(Design Note 0001 §11.2; advances 1/PACI Raw→Draft "executable conformance
for every MUST"). Two vectors added to `circuits/pacioli`:

- `pn_vector_event_is_a_zero_account` — the buyer/supplier event over basis
  `[USD, fabric_meters, garment_units]` balances per dimension (`[10000,50,0]`
  on both sides), no exchange rate asserted.
- `pn_numeraire_collapse_is_rejected` — a journal whose USD column nets but
  whose 50m of fabric vanish is **rejected**: a dimension cannot be settled in
  another. (A scalar/numeraire layer would wrongly accept it.)

## Evidence (`eval-self.sh`, attested)

- present — both vectors exist; the collapse vector asserts `!journal_balanced`.
- test — `nargo test` green on the standalone pacioli crate (7 tests).

Status: open (pre-threshold).
