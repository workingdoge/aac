# Threshold Brief: cand-0008-bvr-clearing-kernel

Generated: 2026-06-13T16:23:12Z
Status: validated
Intent: A non-normative design note at sites/ledger/design/ — the BalancedVectorReceipt / P^n Clearing Kernel: a proof-carrying 2/FACT Event whose private witness compiles (via the canonical rulebook Phi_R) to a P^n transaction zero-account. Records the layered architecture (2/FACT Event -> Phi_R compiler -> BVR/1 application target -> TRANSITION/1 enshrined -> 5/NET -> VNET/1), the doctrine that Phi_R schema-completeness is an APPLICATION target (not enshrined; registry refuses unbalanced state, application targets refuse incomplete receipts, evidence layers grade truth), the separation of VNET/1 (amount-vector netting over P^n via per-dimension Pedersen generators) from 5/NET (fact-occurrence netting over Z[X]), and the in-circuit Poseidon2 vs deliberate homomorphic Pedersen-commitment hash split. Non-normative: informs future 9/PROV/10/ADMIT/12/OTC work, takes no RFC number yet.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/design/README.md` is NEW at `sites/ledger/design/README.md`: 12 lines
- `cargo/sites/ledger/design/0001-bvr-clearing-kernel.md` is NEW at `sites/ledger/design/0001-bvr-clearing-kernel.md`: 284 lines

## Witnessed behavioral delta (task: BVR / P^n clearing-kernel design note (non-normative) — states the BVR object, Phi_R-as-application-target doctrine, VNET/1-vs-5/NET split, the completeness-not-truth boundary, and the Poseidon2/Pedersen hash split; all cross-references resolve)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
