# AAC verification

Two artifacts backing the RFC suite, one boundary: `Core.lean` is the
machine-checked *meaning* of the core algebra; `k-properties.ts` is a
differential harness testing an executable kernel against an independent
reference model of that same algebra. The narrative and the property table
live in [README_TONIGHT.md](README_TONIGHT.md); this file is the current
status and the reproduce instructions.

## `Core.lean` — Lean 4 + mathlib, machine-checked

Double-entry bookkeeping formalized as the Grothendieck group K(M) of amount
vectors. **Compiles clean against mathlib (Lean v4.28.0), zero `sorry`.**
What it establishes:

| Lemma | Statement | RFC / harness |
|---|---|---|
| `pacioliEqual_iff_class_eq` | cross-addition equality = quotient equality — the two faces of K(M) | 1/PACI §2, P4 |
| `balanced_iff_class_zero`, `journal_balanced_iff` | balanced ⟺ class zero | 1/PACI §4, P1 |
| `class_additive` | class(A ⊎ B) = class(A) + class(B) | 1/PACI §3, P3 |
| `class_add_inv` | contra-entry = group inverse | 1/PACI §2 |
| `channel_balanced_iff` | channel balanced ⟺ per-message pushes = pulls | NET/1, P5 |
| `no_double_spend` | nullifier single-pull (rights don't stack) | TRANSITION/1 nullifier |
| `pacioli_equal_field_sound` | u64 bounds ⟹ BN254 field-equality of cross-sums reflects ℕ equality | **3/PROOF §3 carrier injectivity** |
| `journal_sum_field_sound` | the same, generalized to N-row sums (`n·2⁶⁴ ≤ r`) | TRANSITION/1 journal balance |

`pacioli_equal_field_sound` and its N-row generalization `journal_sum_field_sound`
are the keystone: they are the obligation the Noir circuit's `Field → u64 →
Field` range-check discipline discharges — the proof that in-field balance
checks decide *real* balance, with no modular wrap. Per 3/PROOF §3,
"soundness *is* this injectivity."

### Reproduce

Requires [Nix](https://nixos.org). From the repo root:

```sh
nix develop                    # provides elan (the Lean toolchain manager)
cd verification
lake exe cache get             # downloads prebuilt mathlib oleans (minutes)
lake build                     # elaborates Core.lean — success ⟺ zero sorries
```

`lake exe cache get` pulls mathlib's prebuilt oleans from the cloud cache;
there is **no from-source mathlib build**. The toolchain (`lean-toolchain`)
and the exact dependency graph (`lake-manifest.json`) are pinned in this
directory, so the build is reproducible from a clean clone.

## `k-properties.ts` — differential property harness

P1–P6 over randomized inputs (seed `0xC0FFEE`, N=500 → 7,488 checks),
testing an executable kernel against an independently implemented reference
model of K(M). See [README_TONIGHT.md](README_TONIGHT.md) for the property
table and what each one pins.

> Provenance note: this file imports the kernel from `../src/*`, developed in
> a separate tree and **not vendored here**, so it is not yet runnable from
> this repo — it is included as the *specification* of the differential test.
> Making it reproducible (vendoring the kernel and adding the `nargo execute`
> leg so the same random journals exercise the TS kernel, the Lean statements,
> and the Noir circuit together) is part of the implementation work.
