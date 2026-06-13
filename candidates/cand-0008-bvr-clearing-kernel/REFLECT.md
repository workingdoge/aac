# Reflection: cand-0008-bvr-clearing-kernel

Intent: A non-normative design note at sites/ledger/design/ — the BalancedVectorReceipt / P^n Clearing Kernel: a proof-carrying 2/FACT Event whose private witness compiles (via the canonical rulebook Phi_R) to a P^n transaction zero-account. Records the layered architecture (2/FACT Event -> Phi_R compiler -> BVR/1 application target -> TRANSITION/1 enshrined -> 5/NET -> VNET/1), the doctrine that Phi_R schema-completeness is an APPLICATION target (not enshrined; registry refuses unbalanced state, application targets refuse incomplete receipts, evidence layers grade truth), the separation of VNET/1 (amount-vector netting over P^n via per-dimension Pedersen generators) from 5/NET (fact-occurrence netting over Z[X]), and the in-circuit Poseidon2 vs deliberate homomorphic Pedersen-commitment hash split. Non-normative: informs future 9/PROV/10/ADMIT/12/OTC work, takes no RFC number yet.
Status at reflection: landed
Reflected at: 2026-06-13T16:23:13Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0008-bvr-clearing-kernel",
  "evaluated_at": "2026-06-13T16:22:44Z",
  "task": "BVR / P^n clearing-kernel design note (non-normative) — states the BVR object, Phi_R-as-application-target doctrine, VNET/1-vs-5/NET split, the completeness-not-truth boundary, and the Poseidon2/Pedersen hash split; all cross-references resolve",
  "checks": {
    "present": "pass",
    "doctrine": "pass",
    "crossrefs": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "34af6ff663e76b59d0890995a4bf561b4c23a8b83386b5b04e71eed2b9e2c173",
    "traces_sha256": "c4e2d6722dba467edaabd84acbecb9d7a137eda2ab92b5ba2c9d4b51c031a11f",
    "body_sha256": "8ab9f6a5c7988912452f09382999ab80c6594eb1ac9b9021dedc62e90ba7f3d4",
    "attestation": "5654b69818e4fa74a671ff07740199f4e464fc298cdc175a2a49226b6466ca96"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
