# aac_receipt_provekit — a right-sized EVENT-COMPLETE/1 receipt for ProveKit

A **separate** Noir package that re-expresses AAC's EVENT-COMPLETE/1
`BalancedVectorReceipt` on the **ProveKit** toolchain. It is **not** a copy of
`circuits/event-complete` — same semantics, different toolchain, different hash.

## Toolchain (HARD PIN)

| | version | why |
|---|---|---|
| Noir (`nargo`) | **v1.0.0-beta.19** | ProveKit's pin (Design Note 0002 §2.1, confirmed 3-0) |
| ProveKit | pin at integration | `github.com/worldfnd/ProveKit` — pin the commit you build against |
| Proving stack | ACIR → R1CS → **WHIR** (Spartan-style) | ProveKit's pipeline, not bb/UltraHonk |

Install the matching toolchain:

```sh
noirup --version 1.0.0-beta.19
nargo --version   # must report 1.0.0-beta.19
```

### This will NOT compile in the AAC dev shell

AAC's `flake.nix` pins `nargo` **v1.0.0-beta.14** (and in the agent build
environment `nargo` was not even on `PATH`). `Nargo.toml` here sets
`compiler_version = ">=1.0.0-beta.19"`, so **beta.14 will refuse this package** —
deliberately. The beta.14 (`circuits/`, bb/UltraHonk, the 4/REG path) and beta.19
(this package, ProveKit) toolchains **coexist as separate packages** until a
deliberate workspace bump (Design Note 0002 §9). Do **not** add this package to the
`circuits/` workspace and do **not** downgrade it.

## What it proves

The right-sized `BalancedVectorReceipt` (Design Note 0002 §5):

- a small fixed **basis** of 3 incommensurable dimensions
  `[USD_cents, fabric_meters, garment_units]`;
- a small fixed **schema** of 4 rows / 2 roles (Buyer, Supplier);
- **vector debit/credit sums proven equal per dimension** — a Pⁿ zero-account
  (`journal_balanced`), USD cancels USD and fabric cancels fabric, never one through
  another (1/PACI §6, no numeraire);
- **range-bounded non-negative coordinates** via the u64 carrier discipline
  (3/PROOF Annex C);
- a **one-shot event-scoped nullifier** (`!= 0` sentinel);
- **one journal commitment / leaf hash** that a TRANSITION/1 posting would carry.

Obligations realized: EVENT-COMPLETE/1 §4 obligations **2, 4, 5, 9 (event-scoped
narrowing), 10** — the same scoped subset as the beta.14 reference. Deferred
(identical to the reference): 1, 3, 6's per-dimension `MAX_j`, 7, 8, and the
basis/nullifier/evidence recomputations of the full §5 ABI.

## Hash choice is OPEN (do not assume Poseidon2)

ProveKit's **default in-circuit hash is Skyscraper**; Poseidon2 only appears in
ProveKit examples (Design Note 0002 §2.1). This is **not** the same decision as AAC's
bb-workspace Poseidon2 migration (Design Note 0001 §8).

- `src/hash.nr` routes **every** commitment/nullifier/fold through one `hash()`
  function. Switching the primitive is a one-line change.
- It currently uses **Poseidon2 from the Noir stdlib as a PLACEHOLDER** so the
  circuit STRUCTURE typechecks under beta.19. **TODO (verify at integration):** swap
  the body of `hash()` for ProveKit's Skyscraper. The exact import path is
  **unverified** in this environment.
- Consequence: commitment **values differ from the beta.14 `circuits/` circuit**
  (which uses `pedersen_hash`). This is expected — it is a re-expression. If you need
  cross-toolchain commitment equality (a ProveKit receipt whose `journal_commitment`
  matches the registry's pedersen one), that is an **open integration decision** (see
  "Composition", below).

## Flow: prepare / prove / verify (ProveKit CLI)

ProveKit's CLI is three commands (Design Note 0002 §2.1, confirmed 3-0). Exact flag
names are **unverified here** — confirm against the pinned ProveKit:

```sh
# 0. compile the circuit to ACIR (standard nargo)
nargo compile

# 1. prepare — ONCE per circuit: ACIR -> reusable prover key + verifier key
#    (this is the expensive step; cache the keys, ship the prover key to the client)
provekit prepare ./target/aac_receipt_provekit.json -o ./keys

# 2. prove — witness -> WHIR proof. Build the witness from Prover.toml (CLI) or the
#    WASM witness builder (browser; see ../miniapp/src/lib/provekit.ts).
nargo execute            # produces the witness from Prover.toml
provekit prove ./keys/prover.key ./target/witness.gz -o ./proof.bin

# 3. verify — proof + public inputs -> bool (backend; gateway calls this)
provekit verify ./keys/verifier.key ./proof.bin --public-inputs ./public.json
```

Benchmark with ProveKit's own `circuit_stats` / `analyze-pkp` (Design Note 0002
§2.1). **Do not** quote the strategy's reported perf numbers as measured — they were
unverified.

### Witness / public inputs

```sh
cp Prover.toml.example Prover.toml
nargo test --show-output print_public_inputs   # prints the 4 derived commitments
# paste those into Prover.toml, then `nargo execute`
```

The 5 public inputs (order normative), in `main.nr`:
`rulebook_id, event_commitment_pub, participant_set_pub, journal_commitment_pub,
event_nullifier_pub`.

## Browser / WASM (the under-documented part)

In-browser WASM proving is **supported but thinly documented** (Design Note 0002
§2.1, 3-0). The Mini App fetches the prover key once (cache it), builds the witness
in-webview, proves client-side, and posts only `proof + public inputs` to the
gateway. Budget real wrapper time and set an **abort criterion**: if the WASM path
overruns, fall back to **server-side proving** and still ship. See
`../miniapp/src/lib/provekit.ts` for the client stub and `../README.md` for the
abort-criterion note.

## On-chain (optional polish)

Verify the WHIR proof in the backend first. Only if time remains, use ProveKit's
**gnark** recursive verifier to wrap WHIR → **Groth16** on **BN254** and verify
on-chain (e.g. World Chain). Do not start here.

## Composition with the enshrined path (open)

The receipt's `journal_commitment` and `event_nullifier` are the SHARED ledger
primitives a registry posts/consumes — so a receipt is meant to COMPOSE with
TRANSITION/1. But here the hash differs from the beta.14 circuit, so the field
**values** differ. At integration, choose one:

1. fix a single canonical hash across both toolchains (commitment equality holds), or
2. treat the ProveKit receipt as an application-layer attestation re-pinned to the
   registry's pedersen commitments off-circuit.

This is unresolved on purpose — it depends on the Skyscraper-vs-pedersen decision.

## File map

```
provekit-circuit/
  Nargo.toml            # beta.19 pin; standalone (no path deps)
  Prover.toml.example   # a witness template
  src/
    main.nr             # the receipt circuit + tests
    hash.nr             # the ONE hash indirection (Skyscraper TODO)
    pacioli.nr          # journal_balanced + carrier discipline
    rulebook.nr         # Phi_R goods-receipt-invoice compiler
    ledger.nr           # journal_commitment / participant_set / event_nullifier
```
