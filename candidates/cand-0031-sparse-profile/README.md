# cand-0031-sparse-profile

Intent: Define a sparse finite-basis amount/profile representation: fixed slots of per-basis T-account cells with active flags, basis-id bounds, canonical ordering/uniqueness, zero inactive slots, and target-version consequences; no circuit rewrite yet.

Status: open (pre-threshold).

## Cargo

- `sites/ledger/specs/profiles/README.md` introduces the profiles directory.
- `sites/ledger/specs/profiles/SPARSE-CELLS-1.md` defines the sparse
  finite-basis cell profile.
- `sites/ledger/specs/README.md` points to profile definitions.
- `sites/ledger/specs/1/README.md` records that sparse representations are
  conforming only when absent coordinates are zero and the encoding is
  canonical.
- `sites/ledger/specs/3/README.md` records that changing witness obligations or
  commitment preimages for a sparse profile creates a new target identity even
  if public ABI is unchanged.

## Boundary

This candidate does not rewrite circuits, allocate domain tags, update R1,
rename targets, or change any deployed verifier. It defines the profile rules
the later sparse TRANSITION target must discharge.

## Evidence

`eval-self.sh` checks that the profile document contains the load-bearing
requirements: same 1/PACI semantics, fixed sparse cells, active prefix,
strictly-increasing basis ids, inactive-zero canonicalization, active zero-cell
rejection, sparse-to-dense interpretation, state uniqueness, commitment/target
identity consequences, required rejection vectors, and cross-references from
1/PACI, 3/PROOF, and the spec index. A corrupted profile copy with the
strict-ordering requirement removed must fail the same checker.
