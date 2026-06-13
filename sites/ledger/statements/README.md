# AAC verification

`Core.lean` is the machine-checked *meaning* of the core algebra — the
in-repo verification artifact. A differential harness (`k-properties.ts`)
tests an executable kernel against an independent reference model of that
same algebra; it lives with the implementation tree (outside this spec
repo), not here. The narrative and the property table live in
[README_TONIGHT.md](README_TONIGHT.md); this file is the current status and
the reproduce instructions.

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
cd sites/ledger/statements
lake exe cache get             # downloads prebuilt mathlib oleans (minutes)
lake build                     # elaborates Core.lean — success ⟺ zero sorries
```

`lake exe cache get` pulls mathlib's prebuilt oleans from the cloud cache;
there is **no from-source mathlib build**. The toolchain (`lean-toolchain`)
and the exact dependency graph (`lake-manifest.json`) are pinned in this
directory, so the build is reproducible from a clean clone.

## Differential property harness (provenance)

`k-properties.ts` — P1–P6 over randomized inputs (seed `0xC0FFEE`, N=500 →
7,488 checks), testing an executable kernel against an independently
implemented reference model of K(M). See [README_TONIGHT.md](README_TONIGHT.md)
for the property table and what each one pins.

> It imports its kernel from a `../src/*` tree and lives with the
> implementation, not in this spec repo. `Core.lean` above is the in-repo
> verification artifact (and a strictly stronger one — proof, not randomized
> test). The from-scratch Noir build will grow its own differential leg
> (`nargo execute`) with the P1–P6 statements above as the contract.
