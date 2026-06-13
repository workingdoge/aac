# Verification artifacts — design notes (2026-06-11, status updated 2026-06-12)

Two artifacts, one boundary: the executable kernel is the spec's
implementation; the spec is the kernel's meaning. Both target the same five
statements. For current status and reproduce instructions see
[README.md](README.md); this file is the math narrative and the property
table.

## 1. `k-properties.ts` — differential property harness

Differential + property tests of the shipped kernel against an
**independently implemented** reference model of K(M), the Grothendieck
group of fixed-decimal amount vectors.

```
npx tsx k-properties.ts
→ 7488 checks passed, 0 failed  (seed=0xC0FFEE, N=500)
```

> Provenance: this run was green in the kernel's home tree. The harness here
> imports `../src/*`, which is **not vendored into this repo**, so it is the
> *specification* of the differential test, not yet runnable from a clean
> clone. Vendoring the kernel (and adding the `nargo execute` leg below) makes
> it reproducible — see [README.md](README.md).

| Property | Statement | Kernel surface |
|---|---|---|
| P1 | kernel `balanced` ⟺ reference K-class = 0; residuals = exact nets | `journalTrialBalance` |
| P2 | verdict and reduced term invariant under row permutation | `journalTrialBalance`, `equalTerms` |
| P3 | class(A ++ B) = class(A) + class(B) | `addJournalRows`, `addTerms` |
| P4 | cross-addition equality (`pacioli_equal`, the Noir relation) ⟺ equal normal forms | `reduceTerm` vs. circuit relation |
| P5 | channel balanced ⟺ per-(channel,message) pushes = pulls; residuals exact; supports disjoint | `channelTrialBalance` |
| P6 | non-positive multiplicities rejected (monoid guard) | `trialBalanceOriented` |

P4 is the load-bearing one: it tests that the **circuit's equality test**
and the **kernel's normal form** are the same congruence — the two faces of
the Grothendieck quotient agreeing.

Not yet wired: executing the Noir circuits themselves under the same random
inputs (`nargo execute` differential leg). The harness generates the inputs;
adding the nargo loop is a Friday-morning task if wanted, not a blocker.

## 2. `Core.lean` — TYPECHECKED, ZERO SORRIES

Lean 4 + mathlib specification of the core. **Compiles clean against mathlib
(Lean v4.28.0), no `sorry`** (reproduce: [README.md](README.md)):

- `Term.pacioliEqual` — the Grothendieck relation, verbatim the Noir circuit's test
- `K Basis` — the Pacioli group as the quotient (Setoid instance proved inline)
- `balanced_iff_class_zero`, `pacioliEqual_iff_class_eq`, `class_add_inv` — proved
- `class_additive` — proved, via the `total_foldr_init` induction helper
- `journal_balanced_iff` — proved, composing `balanced_iff_class_zero` with `pacioliEqual_iff_class_eq`
- `class_perm_invariant` — the real P2 content is the `LeftCommutative Term.add` instance that makes the journal fold order-free
- `channel_balanced_iff` — proved via `Multiset.ext`
- `no_double_spend` — nullifier single-pull, proved via `Multiset.nodup_iff_count_le_one`
- `pacioli_equal_field_sound` — **the theorem with real content**: bounded
  u64 amounts ⟹ BN254 field equality of cross-sums reflects ℕ equality.
  This is exactly the obligation the `Field → u64 → Field` roundtrip
  discharges. **Proved**, and generalized to the N-row accumulation form
  (`journal_sum_field_sound`, `sum_lt_order`): the per-basis debit/credit
  sums over `n` rows stay below the modulus when `n·2⁶⁴ ≤ r`, which is what
  3/PROOF §3's "every sum the constraints form" actually demands.

## The claim you can defend

> "Core semantics formally specified in Lean and **machine-checked against
> mathlib with zero open obligations**, differentially tested against an
> independent Grothendieck-group reference model (7,488 checks). Field
> soundness — the carrier-injectivity obligation a BN254 circuit must
> discharge — is proved, pairwise and for N-row journal sums. Noir
> implementation and the constraint-level (Clean `FormalCircuit`) binding in
> progress."

## Next steps (post-hackathon, the zkSecurity-shaped work)

1. ~~`lake build` the spec; close the inline proofs.~~ Done.
2. ~~Prove `pacioli_equal_field_sound`.~~ Done, plus the N-row generalization.
3. Bind the spec to Clean's `FormalCircuit` for the transition target so the
   Lean statements tie to the *compiled constraint system*, not a
   verbatim-by-inspection relation; channel statements align with Clean's
   channel ensembles. This is what lifts the bridge from "stated
   correspondence" to "verified compilation chain."
4. Vendor the kernel into this repo and add the nargo differential leg so the
   same random journals exercise the TS kernel, Lean `#eval`, and circuit
   witness generation together.
5. Mechanize the remaining 3/PROOF §4.1 constraint-level obligations (state
   arithmetic `begin+posted=end`, `fact_fold` recomputation, domain
   separation, binarity/implication idioms) — the Draft→Stable gate's "formal
   companion for every soundness-bearing MUST, no open obligation."
