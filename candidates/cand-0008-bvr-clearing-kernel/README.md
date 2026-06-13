# cand-0008-bvr-clearing-kernel

A **non-normative design note** at `sites/ledger/design/` — the
BalancedVectorReceipt / Pⁿ Clearing Kernel. Captures the architecture from the
2026-06-13 design conversation: the canonical object (a proof-carrying 2/FACT
Event whose private witness compiles via the rulebook Φ_R to a Pⁿ transaction
zero-account), the layered stack (2/FACT Event → Φ_R → BVR/1 → TRANSITION/1 →
5/NET → VNET/1), and three load-bearing decisions:

- **Φ_R completeness is an APPLICATION target (BVR/1), not enshrined.** The
  registry refuses unbalanced state; application targets refuse incomplete
  receipts; evidence layers grade truth. (Respects 3/PROOF §4, 4/REG §5.)
- **VNET/1 ≠ 5/NET.** Amount-vector netting over Pⁿ (per-dimension Pedersen
  generators) is a different invariant from channel-fact netting over ℤ[X].
- **Hash split:** Poseidon2 for in-circuit roots/folds (~48× cheaper, no
  homomorphism needed); homomorphic Pedersen *vector commitment* only where
  native cross-receipt netting earns it.

Records that AAC already proves vector zero-accounts (Core.lean K(Amount),
1/PACI ℕ^B, circuits/pacioli per-basis) — the new work is schema-complete
receipts, not vector balance.

## Evidence (`eval-self.sh`, attested)

- present — note + index exist, marked non-normative, disclaim RFC status.
- doctrine — BVR object + Φ_R-as-application-target + VNET/5NET split +
  completeness-not-truth boundary + the Poseidon2/Pedersen split all stated.
- crossrefs — every spec/code artifact the note leans on exists; the core
  claims (Core.lean `Basis → ℕ`, 1/PACI ℕ^B + no-valuation, pacioli per-basis)
  verify against the tree.

Status: open (pre-threshold).
