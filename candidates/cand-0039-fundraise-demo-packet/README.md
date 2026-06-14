# cand-0039-fundraise-demo-packet

Intent: Add an executable FUNDRAISE-CLEARING/1 demo packet and reference checker that bind round policy, subscriptions, settlement/admissibility reports, VNET transition-link verification, and mint authorization; include rejection fixtures for price, settlement, token, and VNET failures.

## Cargo

- `sites/ledger/specs/applications/reference/fundraise_demo.py` -- a
  dependency-free transparent checker/generator for a concrete
  FUNDRAISE-CLEARING/1 demo packet. It checks policy price/caps, subscription
  settlement/admissibility reports, nullifier discipline, mint authorization
  binding, and delegates VNET transition-link + amount-netting to the landed
  VNET checker.
- `sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json` -- generated
  fixtures covering accepted private-balance-sheet fundraising plus price,
  missing-settlement, token-contract, and VNET false-net rejection cases.
- `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` -- implementation
  status cross-reference to the demo checker and fixture packet.

No circuit, native verifier, token contract, settlement adapter, CRE workflow,
Circle integration, or ProveKit integration is included in this slice.

Status: open (pre-threshold).
