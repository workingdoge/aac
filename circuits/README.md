# AAC circuits — TRANSITION/1 in Noir

The trusted state-transition surface of the root registry (4/REG), proved in
[Noir](https://noir-lang.org). This is the worldly realization of the spec
suite under `sites/ledger/specs` and the algebra machine-checked in
`sites/ledger/statements/Core.lean`.

```
circuits/
  pacioli/      library crate — the K(M) balance primitives (the in-circuit
                face of Core.lean: pacioli_equal, term_balanced,
                journal_balanced, the Field->u64->Field bound)
  transition/   binary crate  — TRANSITION/1 (3/PROOF S4.1)
```

## What TRANSITION/1 proves

> A private journal, balanced per the deployment's locality option (1/PACI S3),
> applied to a committed private account state, yields the committed next state;
> consumed rights chain the nullifier root; emitted channel facts fold into
> `fact_fold` in journal order.

Public ABI (order normative, 3/PROOF S4.1):

| # | name | role |
|--:|------|------|
| 0 | `prev_account_root` | recomputed from `prev_state`, equated to trusted root |
| 1 | `next_account_root` | recomputed from `begin + posted` |
| 2 | `prev_nullifier_root` | trusted context |
| 3 | `next_nullifier_root` | chained; unchanged unless a right is consumed |
| 4 | `journal_commitment` | recomputed, order-binding fold over rows |
| 5 | `context_commitment` | `unconstrained` — bound by the 4/REG row |
| 6 | `fact_fold` | Annex B fold over emitted facts, journal order |
| 7 | `fact_count` | number of emitted facts |

### Constraints

- **Carrier injectivity (the soundness pivot).** Every amount is a `u64`. Each
  per-basis sum the balance check forms is therefore `< n * 2^64 << r` (the
  BN254 scalar order), so in-field equality of the debit and credit columns
  decides integer equality with no wraparound. This is exactly the obligation
  proved in `journal_sum_field_sound` (Core.lean) — the circuit's
  `Field -> u64 -> Field` discipline is `pacioli::assert_u64`, applied to every
  amount-bearing witness including the *resulting* account balances.
- **Journal balance** per basis (1/PACI S3 journal-locality): `pacioli::journal_balanced`.
- **State arithmetic**: `begin + posted = end`, per account, per basis, the end
  state Merkleized into `next_account_root`.
- **Nullifiers**: pairwise distinct, nonzero; the root folds from `prev`; empty
  slots leave it untouched, so the root is provably unchanged absent consumption.
- **Facts**: side is binary (`s*(s-1)=0`); an active fact's multiplicity is `>= 1`.
- **Domain separation**: every in-circuit hash carries a leading tag (3/PROOF
  Annex A, TRANSITION family); the fold seed is `H(tag || "fact_fold/1")`.

Correspondence to `Core.lean` (machine-checked, zero `sorry`):

| Noir | Lean |
|------|------|
| `pacioli_equal` | `Term.pacioliEqual` |
| `term_balanced` | `Term.balanced` / `balanced_iff_class_zero` |
| `journal_balanced` | `Journal.balanced` |
| `assert_u64` over a journal | `journal_sum_field_sound` |

## Build · test · prove

Requires `nargo` (Noir) — pinned to `v1.0.0-beta.14` in the repo `flake.nix`.
Install standalone with [`noirup`](https://noir-lang.org/docs/getting_started/quick_start)
(`noirup --version 1.0.0-beta.14`) or enter `nix develop`.

```sh
cd circuits
nargo compile           # type-check + synthesize ACIR for every crate
nargo test              # the conformance gate: accept valid, reject
                        #   unbalanced / tampered-root / double-spend /
                        #   zero-multiplicity; plus the pacioli lib laws
nargo execute           # solve the witness for the sample in Prover.toml
nargo info              # gate counts (main ~ 775 ACIR opcodes)
```

`nargo` compiles, tests, and executes on any platform. Generating the actual
UltraHonk proof (`profile uh-bn254/1`) and verification key uses Barretenberg:

```sh
bb prove    -b target/transition.json -w target/transition.gz -o target/proof
bb write_vk -b target/transition.json -o target/vk
```

The pinned `bb` (v2.1.8) ships an `x86_64-linux` binary only; proof generation
runs in a Linux prover environment (the registry verifier consumes
`(circuit_hash, vk_hash)` — provers are never the source of either, 3/PROOF S2).
The constraint system itself — what soundness depends on — is fully exercised
by `nargo test`/`execute` here.

## Scope (honest)

This is the default profile (journal-level locality) over a fixed sub-state
shape (`N_BASIS=3`, `N_ROWS=4`, `N_ACCT=4`, `N_NULL=2`, `N_FACT=2`; a deployment
records its shape in Register R1). The account root is a depth-2 binary Merkle
recomputed in full from the committed sub-state. The nullifier root is an
insertion-chained accumulator with batch-local distinctness; cross-batch
non-membership against the historical set is NULLIFY/1's dedicated job
(3/PROOF S4.2). Entry-level locality, variable shapes, and the aggregation
target (TRANSITION-AGG/1, 3/PROOF S4.4) are follow-on work.
