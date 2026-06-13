# world-app — AAC World Stack MVP scaffold

A **prototype scaffold** for shipping AAC as a **human-backed clearing copilot** in a
World Mini App: World ID makes scarce access fair *per human*, AgentKit lets a
human-backed agent operate safely, ProveKit makes a balanced-receipt proof practical
on the client, and human-in-the-loop keeps the last mile of financial commitment
under explicit human control.

> This is the implementation of **Design Note 0002**
> (`sites/ledger/design/0002-world-stack-agentkit-provekit.md`). That note is the
> spec; this directory obeys its verified corrections. Nothing outside `world-app/`
> is modified.

## Architecture — the narrow waist

The World-specific logic stays at the **edges**; the AAC core (Pⁿ balance, Φ_R
compilation, the registry's refusals) is untouched.

```
┌─────────────────────────── World Mini App (miniapp/) ───────────────────────────┐
│  walletAuth() sign-in                                                            │
│  World ID uniqueness proof ──▶ one-per-human starter credits (keyed by nullifier)│
│  AgentBook registration (agent wallet, default World Chain eip155:480)           │
│  ProveKit client-side proof  (witness build ▸ WASM prove ▸ server fallback)      │
│  HITL approval  requestHumanAuthorization → bound to receipt:<nullifier>         │
└───────────────────────────────────────┬─────────────────────────────────────────┘
                                         │  agentkit client.fetch (402 → sign → retry)
                 ══════════════ NARROW WAIST: x402 + agentkit ═══════════════
                                         │
┌─────────────────────────── Agent Gateway (gateway/) ────────────────────────────┐
│  402 + agentkit challenge (nonce issued + persisted)                             │
│  parse ▸ validate ▸ verifySignature ▸ AgentBook resolve → anonymous HumanRef     │
│  consume one-time nonce (replay defence)                                         │
│  per-human SHARED counter (free / free-trial / discount)  ← N agents, 1 quota    │
│  proxy to AAC service   (or fall back to x402 / MiniKit pay)                      │
└───────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
┌─────────────────────────── AAC Services (stubbed here) ─────────────────────────┐
│  quote / matching / proof-gen / financing                                        │
│  receipt verification (WHIR in backend; optional Groth16 on World Chain)         │
│  optional World Chain anchoring (4/REG) — unchanged                              │
└─────────────────────────────────────────────────────────────────────────────────┘

ProveKit circuit (provekit-circuit/): a right-sized EVENT-COMPLETE/1
BalancedVectorReceipt — small basis, vector per-dimension balance, range-bounded
coordinates, one-shot nullifier, one commitment. Separate Noir beta.19 package.
```

## Verified vs stubbed — the precise table

"Verified" = the named API surface is the deep-research-confirmed one from Design
Note 0002 §2 (vote tally in parens). "Real" = runnable code in this scaffold.
"Stub" = throws "verify-at-integration". The whole World surface is **Beta**.

| capability | named surface (verified?) | in this scaffold |
|---|---|---|
| Mini App sign-in | `walletAuth()` (3-0) | **stub** — `miniapp/src/lib/worldid.ts` |
| World ID backend verify | `POST /api/v4/verify/{rp_id}` (3-0) | route constant only; **stub** |
| uniqueness → one-per-human credits | one-time nullifier per action (2-1) | **real** credit store keyed by nullifier; proof call **stub** |
| AgentBook lookup chain | World Chain `eip155:480` (**2-1, weak**) | **config default**, not hard-coded; registration **stub** |
| AgentBook registration transport | direct vs relay — **UNRESOLVED**; "Base relay" **REFUTED (0-3)** | **stub**, documented as open |
| AgentKit client | `createAgentkitClient(...).fetch` (3-0) | **stub** — `miniapp/src/lib/agentkit-client.ts` |
| AgentKit server helpers | `parseAgentkitHeader`, `validateAgentkitMessage`, `verifyAgentkitSignature`, `createAgentBookVerifier` (3-0) | **stub** (names wired, signatures unverified) — `gateway/src/core/agentkit.ts` |
| 402 + challenge / nonce issue | x402 + agentkit extension (3-0) | **real** — `gateway/src/core/gateway.ts` |
| per-human SHARED counter | per-human-per-endpoint, agents share (3-0) | **real** — `gateway/src/core/policy.ts` |
| access policies | `free` / `free-trial` / `discount` (3-0) | **real** — `demoPolicies()` |
| persistent storage (counters+nonces) | `InMemoryAgentKitStorage` is dev-only (3-0) | **interface real**; in-memory impl **DEV-ONLY**; DB adapter TODO |
| HITL approval | `requestHumanAuthorization`, action id customizable (3-0) | **stub**, bound to `receipt:<nullifier>` — `miniapp/src/components/ApprovalCheckpoint.tsx` |
| ProveKit pipeline | Noir→ACIR→R1CS→WHIR, `prepare`/prove/verify (3-0) | circuit + flow documented; **not compiled here** (toolchain) |
| ProveKit in-circuit hash | **Skyscraper default** (Poseidon2 in examples) | Poseidon2 **placeholder** behind one indirection; Skyscraper **TODO** |
| browser WASM proving | supported (3-0) but thin docs | witness build **real**; WASM prove **placeholder**; server fallback **real** |
| on-chain recursion | gnark → Groth16 on BN254 (3-0) | documented as optional polish; not built |
| receipt circuit semantics | EVENT-COMPLETE/1 BVR (`circuits/event-complete`) | **re-expressed**, obligations 2/4/5/9-scoped/10 — `provekit-circuit/` |

## Toolchain + versions

| component | version | notes |
|---|---|---|
| ProveKit circuit (Noir / `nargo`) | **v1.0.0-beta.19** | ProveKit's pin. **DIFFERENT** from AAC's `circuits/` (beta.14). |
| AAC `circuits/` workspace (untouched) | beta.14 | bb/UltraHonk, the 4/REG path. Coexists as a separate package. |
| Mini App | React 18 + Vite 5 + TypeScript 5.5 + MiniKit (Beta, pin at integration) | |
| Gateway | Node ≥20 + TypeScript 5.5, Hono 4 example, AgentKit SDK (Beta, pin at integration) | |
| Proving stack | ACIR → R1CS → WHIR (Spartan-style); optional gnark→Groth16/BN254 | not bb/UltraHonk |

### This environment could NOT compile the circuit

The AAC dev shell pins `nargo` **beta.14** (`flake.nix`); in the agent build env
`nargo` was not even on `PATH`. The ProveKit circuit pins **beta.19**, so it will
**not** compile here — **this is expected**, not a failure. Install `noirup --version
1.0.0-beta.19` and run `nargo test` / `nargo compile` where the ProveKit toolchain
lives. The TypeScript (gateway core + miniapp) **does** typecheck here (verified:
`tsc --noEmit` clean in both packages, with the Hono example excluded as an optional
peer dep).

## Beta / unresolved caveats (carried from Design Note 0002)

- **Everything World is Beta and moving.** Pin versions; state which you demoed; do
  not hard-code old examples (§9).
- **AgentBook chain partly unresolved.** Lookup-on-World-Chain (`eip155:480`) is only
  weakly confirmed (2-1); "Base mainnet relay" is refuted (0-3); the **registration
  transport** (direct vs relay, which chain) is a genuine open question. Config, not
  hard-coded (§2.2, §9).
- **ProveKit hash choice OPEN.** Skyscraper (default) vs Poseidon2 (examples) — decide
  by measurement; **not** the same decision as the bb-workspace Poseidon2 migration
  (§2.1, §9).
- **ProveKit browser glue is thin.** Budget wrapper work; CLI/mobile are better
  documented. Set an **abort criterion** → server-side proving (§2.1, §5). Wired into
  `proveReceipt(...)`.
- **Perf unverified.** Do **not** quote the strategy's prove/verify numbers as
  measured. Benchmark with ProveKit's `circuit_stats` / `analyze-pkp` (§2.1).
- **Noir version split is permanent for now.** beta.14 (`circuits/`) and beta.19
  (`provekit-circuit/`) coexist as separate packages until a deliberate bump (§9).
- **Cross-toolchain commitment equality is open.** The ProveKit circuit hashes with a
  sponge (Skyscraper/Poseidon2), the beta.14 circuit with pedersen — so commitment
  values differ. Composing a ProveKit receipt with the registry's pedersen
  commitments is an integration decision (see `provekit-circuit/README.md`).

## Integration TODO checklist

ProveKit circuit
- [ ] install `nargo` beta.19; `nargo test` then `nargo compile` the circuit
- [ ] replace the Poseidon2 placeholder in `provekit-circuit/src/hash.nr` with
      ProveKit **Skyscraper**; recompute the public commitments
- [ ] `provekit prepare` → prover/verifier keys; serve the prover key under
      `miniapp/public/keys/`
- [ ] benchmark with `circuit_stats` / `analyze-pkp` (do not trust quoted numbers)
- [ ] decide cross-toolchain commitment policy (one canonical hash, or off-circuit
      re-pin to the registry's pedersen commitments)

Mini App
- [ ] install + wire MiniKit (`walletAuth`, World ID verify); confirm package name
- [ ] wire the World ID HITL `requestHumanAuthorization`; keep the
      `receipt:<nullifier>` action binding
- [ ] wire `createAgentkitClient` (the agent's signing fetch)
- [ ] wire the ProveKit **WASM** prove path in `lib/provekit.ts proveInBrowser`;
      keep the abort-criterion fallback

Gateway
- [ ] wire the four AgentKit server helpers in `core/agentkit.ts` (remove the stub
      throws); confirm signatures + the credential header name
- [ ] fix the nonce binding to use the **parsed** nonce (see `core/gateway.ts` TODO)
- [ ] implement a **DB-backed** `GatewayStorage` with atomic increment + nonce
      consume; drop `InMemoryGatewayStorage`
- [ ] point `HttpAacService` at the real AAC backend
- [ ] confirm the AgentBook chain/transport against the live SDK

Optional polish
- [ ] gnark recursive verifier: WHIR → Groth16 on World Chain
- [ ] anchor the receipt/transition via 4/REG on World Chain

## Layout

```
world-app/
  README.md              ← this file
  miniapp/               ← React/MiniKit Mini App skeleton (typechecks clean)
  gateway/               ← AgentKit x402 gateway, framework-agnostic + Hono example
  provekit-circuit/      ← Noir beta.19 right-sized EVENT-COMPLETE/1 receipt
```

## Scope discipline

This scaffold lives **only** under `world-app/`. It does not touch `circuits/`,
`registry/`, `candidates/`, `QUEUE.md`, `memory/`, `flake.nix`, `sites/`, `web/`, or
`tools/`, and it is **not** a `tools/loop` candidate. The ProveKit circuit is an
**optional application-layer addition**, never a replacement of the bb/UltraHonk +
4/REG path (Design Note 0002 §8).
