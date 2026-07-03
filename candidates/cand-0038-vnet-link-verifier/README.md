# cand-0038-vnet-link-verifier

Intent: Add a reference VNET link verifier and fixtures: bind VNET-BN254-G1 atoms to accepted TRANSITION/1 registry reports plus companion link certificates, then reject missing transition refs, journal mismatches, link-certificate mismatches, and false nets.

## Cargo

- `sites/ledger/specs/applications/reference/vnet_link_verifier.py` -- a
  dependency-free reference checker/generator that imports the
  `VNET-BN254-G1/1` profile checker, validates transition reports, validates
  companion link certificates, then delegates amount-netting to the profile
  checker.
- `sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json` -- generated
  fixtures covering accepted link+netting, missing transition ref, journal
  commitment mismatch, link-certificate mismatch, and false-net rejection.
- `sites/ledger/specs/applications/VNET-1.md` -- implementation-status
  cross-reference to the reference link verifier.

No circuit, native verifier, registry integration, or ProveKit integration is
included in this slice. The verifier is a transparent reference path for the
link semantics only.

Status: open (pre-threshold).
