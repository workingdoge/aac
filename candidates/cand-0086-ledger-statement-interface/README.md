# cand-0086-ledger-statement-interface

Intent: Define LEDGER/1 as the committed private ledger state and statement interface, giving fundraise demo its missing 0-simplex.

## Cargo

- `sites/ledger/specs/applications/LEDGER-1.md` -- Raw application-surface
  specification defining committed private ledgers, statement requests,
  statement receipts, projection law, and transition binding.
- `sites/ledger/specs/applications/README.md` -- index row and wording update
  so application surfaces can live beside application targets without claiming
  base-registry status.

Boundary: this candidate does not add a circuit, proof target, domain tag,
contract, runtime, or web UI. It names the ledger vertex that existing
TRANSITION/1, VNET/1, BCC/1, and FUNDRAISE-CLEARING/1 work can bind to in
later candidates.

Status: open (pre-threshold).
