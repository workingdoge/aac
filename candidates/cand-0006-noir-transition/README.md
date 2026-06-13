# cand-0006-noir-transition

The **TRANSITION/1** Noir circuit (3/PROOF S4.1) — the trusted state-transition
surface of the root registry (4/REG), and the first worldly realization of the
AAC spec suite. Lands a Nargo workspace at `circuits/`:

- `circuits/pacioli/` — the K(M) balance primitives, the in-circuit face of
  `sites/ledger/statements/Core.lean` (`pacioli_equal`, `term_balanced`,
  `journal_balanced`, the `Field->u64->Field` bound).
- `circuits/transition/` — TRANSITION/1: journal balance, `begin+posted=end`
  state arithmetic, recomputed account/nullifier roots (nullifier root provably
  unchanged absent consumption), `fact_fold` per Annex B with domain tags,
  recomputed `journal_commitment`, `unconstrained` `context_commitment`.

**Soundness pivot:** every amount is a `u64`, so the per-basis balance sums
cannot wrap the BN254 scalar order — the obligation `journal_sum_field_sound`
discharges in Core.lean, realized in-circuit by `pacioli::assert_u64`.

## Evidence (`eval-self.sh`, attested)

- `nargo compile` — pacioli + transition synthesize (main ~775 ACIR opcodes).
- `nargo test` — accept a valid transition; reject unbalanced journal, tampered
  next-root, double-spent nullifier, zero-multiplicity fact; plus the pacioli
  laws (cross-addition, balance, the u64 roundtrip over/under 2^64).
- `nargo execute` — the sample witness (`Prover.toml`) solves.
- lean-link — the circuit is wired to `journal_sum_field_sound`.

`nargo` is pinned to `v1.0.0-beta.14` in `flake.nix`. Proof generation (`bb`,
`uh-bn254/1`) needs a Linux prover env; the constraint system that soundness
rests on is fully exercised by the tests/execute here. See `circuits/README.md`.

Status: open (pre-threshold).
