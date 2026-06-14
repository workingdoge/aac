# cand-0034-vnet-pedersen

Defines VNET/1 as a Raw non-enshrined application target for amount-vector
netting over posted TRANSITION/1 journals.

## Cargo

- `sites/ledger/specs/applications/VNET-1.md` — new Raw target spec for
  Pedersen vector commitments, transition linkage, and aggregate zero-opening.
- `sites/ledger/specs/applications/README.md` — application-target index row.
- `sites/ledger/specs/applications/EVENT-COMPLETE-1.md` — updates the VNET
  placeholder to point to the new spec.

No circuit, registry, tool, or R1 tag allocation is included in this slice.

Intent: Define VNET/1 as a non-enshrined amount-vector netting target: Pedersen vector commitments per basis, zero-opening proof, and explicit linkage back to posted TRANSITION/1 journal commitments.

Status: open (pre-threshold).
