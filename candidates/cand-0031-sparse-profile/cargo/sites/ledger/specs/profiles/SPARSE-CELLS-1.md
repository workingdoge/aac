# SPARSE-CELLS/1 -- Sparse finite-basis amount cells

- Name: SPARSE-CELLS/1 . Status: Raw . Profile for 1/PACI + 3/PROOF targets
- Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 3/PROOF.

This profile gives a canonical sparse representation for the default 1/PACI
amount domain `N^B`: vectors of non-negative atomic units over a finite basis
`B`, with a declared coordinate bound `N`.

It does **not** change the semantic object. A term remains an ordered pair
`(debit, credit) in M x M`; a journal remains balanced iff its total class is
zero in `K(M)`. SPARSE-CELLS/1 only changes how a proof target witnesses and
commits to the per-basis coordinates.

## 1. Parameters

A SPARSE-CELLS/1 target declaration fixes:

| parameter | meaning |
|---|---|
| `basis_count` | number of admitted basis dimensions, indexed `0..basis_count-1` |
| `slot_count` | maximum number of non-zero basis cells carried by one term |
| `amount_bound` | exclusive upper bound for every debit/credit coordinate |
| `basis_order` | canonical order of basis identifiers |

`basis_count`, `slot_count`, `amount_bound`, and `basis_order` are part of the
target's constraint obligations. A change to any of them is a new target
identity under 3/PROOF.

## 2. Cell encoding

A sparse term is a fixed-length array:

```text
SparseCell := {
  active:   bit,
  basis_id: uint,
  debit:    uint,
  credit:   uint
}

SparseTerm := [SparseCell; slot_count]
```

The interpretation of a sparse term as the dense 1/PACI term `(d, c)` is:

```text
d[b] = sum_i active_i * [basis_id_i = b] * debit_i
c[b] = sum_i active_i * [basis_id_i = b] * credit_i
```

where absent basis coordinates contribute zero.

## 3. Canonical form

A conforming SPARSE-CELLS/1 witness MUST enforce all of the following:

1. `active` is binary.
2. Active cells have `basis_id < basis_count`.
3. Active cells have `debit < amount_bound` and `credit < amount_bound`.
4. Active cells are a prefix of the slot array: after the first inactive cell,
   every later cell is inactive.
5. Active cells are strictly increasing by `basis_id`. This gives uniqueness
   and canonical ordering.
6. Inactive cells are exactly zero: `basis_id = 0`, `debit = 0`, and
   `credit = 0`.
7. An active cell with `debit = 0` and `credit = 0` MUST be rejected; the
   canonical representation of an absent coordinate is an inactive cell.

The profile does not require debit and credit support inside an active cell to
be disjoint. Raw 1/PACI terms may carry both sides at the same basis coordinate;
residual or reduced-normal-form profiles may add a disjoint-support
requirement, but SPARSE-CELLS/1 does not.

## 4. Balance and state arithmetic

A target using SPARSE-CELLS/1 MUST decide journal balance by the dense
interpretation above: for every basis `b`, the total debit for `b` equals the
total credit for `b`.

State arithmetic is likewise per account and per basis:

```text
end(account, b).debit  = begin(account, b).debit  + posted(account, b).debit
end(account, b).credit = begin(account, b).credit + posted(account, b).credit
```

Missing `(account, basis)` cells are zeros. If state is represented sparsely, a
target MUST enforce canonical uniqueness over the key it uses for state cells:
`(account, basis_id)` for a flat state table, or `basis_id` within each
account-local table.

## 5. Commitments and target identity

A SPARSE-CELLS/1 commitment preimage MUST include every slot's
`active`, `basis_id`, `debit`, and `credit` in canonical slot order, together
with the account key wherever the target commits a posting or account state.

No existing target may silently reinterpret an old dense commitment as a sparse
commitment. If a target changes constraint obligations or commitment preimages
to use SPARSE-CELLS/1, it is a new target identity under 3/PROOF, even if its
public ABI names and order are unchanged.

A target MAY use sparse cells internally while densifying to an existing dense
commitment preimage, but then it MUST prove the sparse-to-dense interpretation
inside the circuit and MUST state that compatibility in its target declaration.

## 6. Rejection vectors

A conformance suite for a SPARSE-CELLS/1 target MUST include corrupted-input
cases for at least:

- duplicate active `basis_id`;
- unsorted active `basis_id`;
- a gap in the active prefix;
- non-zero inactive-cell junk;
- active zero-zero cells;
- `basis_id >= basis_count`;
- amount coordinates outside `amount_bound`;
- a journal where a basis coordinate vanishes by omission rather than being
  credited.

## 7. Security considerations

The hazards are non-canonical encodings and selector misuse. Duplicate basis
cells, inactive junk, and unsorted active cells allow multiple witnesses for the
same abstract term and can make commitment equality ambiguous. Missing
basis-id bounds or unconstrained selectors can settle one basis as another.
Every SPARSE-CELLS/1 target therefore treats canonical form as a soundness
obligation, not a serialization preference.

