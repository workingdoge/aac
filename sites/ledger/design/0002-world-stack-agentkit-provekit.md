# Design Note 0002 — The World Stack for AAC: AgentKit + ProveKit

- Status: **non-normative design sketch** (NOT an RFC; takes no permanent number)
- Editor: Arjun Velagapudi
- Touches: 2/FACT, 3/PROOF, 4/REG; the EVENT-COMPLETE/1 application target; informs future 9/PROV, 10/ADMIT, 12/OTC
- Provenance: records a strategy conversation, 2026-06-13, fact-checked against a
  deep-research pass the same day (5 angles, 21 sources, 25 claims under 3-vote
  adversarial verification). Where the original strategy and the verified record
  disagree, the verified record wins and the correction is called out inline.

> **One line.** AAC proves *the books balance*. ProveKit makes that proof
> practical on the client. World ID makes scarce access *fair per human*.
> AgentKit lets a human-backed agent operate safely. Human-in-the-loop keeps the
> last mile of financial commitment under explicit human control.

This note is a non-normative sketch. It changes no specification. It records a
hackathon-grade architecture for shipping AAC as a **human-backed clearing
copilot** inside a World Mini App, and fixes the integration seams so later work
can decide what becomes permanent.

## 1. Why the World stack fits AAC

AAC's scarce resources are not page views; they are **free proof generation,
trial access to quote/matching APIs, and sensitive actions** — financing
acceptance, receipt issuance, note assignment, collateral release, settlement.
Payments alone cannot tell you how many *humans* are behind a swarm of agents:
one person can run many wallets. World's thesis is exactly this cardinality
problem — proof-of-human lets a service rate-limit and allocate scarce access
*per person* rather than per wallet or per script. That is the fairness and
anti-Sybil story a clearing product actually needs.

So the strongest posture is **a human-backed clearing copilot**: a verified
human launches a Mini App, delegates to an agent, the agent gets per-human
starter access to protected AAC endpoints, the app generates a client-side proof
for a narrow AAC receipt, and any irreversible financial action requires an
explicit human approval bound to that action.

## 2. Verified facts (2026-06-13)

This section is the load-bearing one: it corrects the original strategy where
research contradicts it. Treat version pins and chain IDs as *verify-at-
integration* — the entire surface is Beta and moving.

### 2.1 ProveKit (`github.com/worldfnd/ProveKit`)

- **Noir version pin — CORRECTED.** The original strategy said ProveKit requires
  Noir `v1.0.0-beta.11`. **It does not** — the repo currently pins
  **`v1.0.0-beta.19`** (confirmed 3-0 against `package.json` / CI / README). AAC
  is on **`beta.14`**, so AAC is *behind* ProveKit, not ahead. Consequence: a
  ProveKit circuit must be a **separate package on beta.19**, isolated from the
  bb/UltraHonk workspace (which stays on beta.14). Do NOT downgrade to beta.11
  (stale) and do NOT migrate the whole workspace in a weekend.
- **Pipeline.** Noir -> ACIR -> **R1CS**, proven with **WHIR** (a
  polynomial-commitment scheme) over a **Spartan**-style R1CS argument. The CLI
  flow is three commands: `prepare` (once per circuit -> reusable prover key +
  verifier key), prove (witness -> proof), verify. (3-0.)
- **Recursive / on-chain path.** A **gnark**-based recursive verifier wraps the
  WHIR proof into a **Groth16** outer proof on **BN254**, verifiable on an EVM
  chain (e.g. World Chain). The clean escalation: verify WHIR in the backend
  first; only if time remains, wrap to Groth16 and verify on-chain. (3-0.)
- **Browser/WASM — CAVEAT.** In-browser WebAssembly proving is **supported**
  (3-0) but **under-documented**: there is a WASM demo, yet the CLI / iOS /
  Android paths are far better tutorialized than browser glue. Expect to write a
  thin wrapper. This is real hackathon work, not a freebie.
- **In-circuit hash — CORRECTED NUANCE.** The strategy said "prefer Poseidon2."
  ProveKit's **default hash is Skyscraper**; Poseidon2 appears in examples. So
  ProveKit's hash preference does **not** automatically coincide with AAC's open
  Poseidon2-migration item (track C) — the ProveKit circuit may want Skyscraper.
  General guidance still holds: field arithmetic, batched range checks, and
  memory ops are cheap; avoid SHA-256 unless you need external compatibility.
- **Performance — UNVERIFIED, measure it.** The strategy's quick-start numbers
  (~45,123 R1CS constraints -> ~2.3 MB prover key, ~128 KB verifier key, ~18.4 KB
  proof, ~1.8 s prove, ~47 ms verify) were NOT confirmed in this pass; cite them
  as "reported, unverified." For *rough* scale only, AAC's TRANSITION/1 is
  **40,511 UltraHonk gates** (measured via `bb gates`) — but **UltraHonk gates
  and R1CS constraints are different metrics**, so this is a plausibility check,
  not an equivalence. Client-side proving of a *right-sized* receipt is plausible
  but must be benchmarked with ProveKit's own `circuit_stats` / `analyze-pkp`.

### 2.2 World AgentKit (`docs.world.org/agents/agent-kit`)

- **What it is.** AgentKit extends **x402** so a service can distinguish
  **human-backed agents** from arbitrary automation, and meter access per human.
  Beta. (3-0.)
- **The 402 flow.** The server answers a protected route with `402 Payment
  Required` advertising an `agentkit` extension challenge; the client's
  `createAgentkitClient(...).fetch(...)` inspects the 402, signs the challenge
  (x402 / CAIP-122), and retries. Server-side hooks verify the signature,
  resolve the agent wallet to an anonymous human via **AgentBook**, and apply the
  policy. (3-0.)
- **AgentBook chain — CORRECTED, but partly unresolved.** Per the SDK reference,
  AgentBook **lookup resolves on World Chain (`eip155:480`)** — but this is only
  **weakly confirmed (2-1)**, and the more specific "resolves on World Chain, not
  Base" framings were themselves **contested (1-2)**. What IS firmly refuted is
  the original strategy's "gasless relay on **Base mainnet**" (refuted **0-3**),
  so do NOT state "registration on Base." Net: treat the *lookup* chain as World
  Chain, but the **registration transport — direct submission vs a relay, and on
  which chain — is a genuine open question.** Confirm against the live SDK at
  integration time; do not hard-code it.
- **Per-human counters.** Usage counters are tracked **per human per endpoint**,
  and **multiple agents backed by the same human SHARE one counter** (3-0). This
  is the anti-Sybil core: ten agent wallets cannot claim ten starter quotas.
- **Access policies.** `free`, `free-trial`, and `discount` modes ship in the
  SDK; trial/discount usage limits are enforced server-side against the shared
  per-human counter. A sane demo starter policy: e.g. 3 free quote requests OR 3
  free proof-gen attempts OR 1 free financing-run per human-backed agent family,
  then fall back to x402 payment or a MiniKit pay.
- **SDK surface.** The named helpers exist (3-0): the client
  `createAgentkitClient`, and server-side `parseAgentkitHeader`,
  `validateAgentkitMessage`, `verifyAgentkitSignature`, `createAgentBookVerifier`
  — so AgentKit can be a **verification layer**, not a framework choice.
  `InMemoryAgentKitStorage` is **dev-only**; production must persist usage
  counters + replay nonces (build a small DB-backed adapter — replay protection
  is part of the fairness story). Hono/`@x402/hono` is the maintained example,
  but Express and Next.js route handlers can use the same hooks — though if AAC's
  backend is Express/Next, budget for the adapter layer; it is not zero-cost.

### 2.3 World ID 4.0 + Mini Apps (`docs.world.org/world-id`)

- **Backend verify endpoint.** `POST /api/v4/verify/{rp_id}` (3-0).
- **Two proof types.** **Uniqueness** proofs are scoped to an `action` and
  return a **one-time nullifier** (enforced one-time per action, 2-1);
  **Session** proofs carry a `session_id` and return a `session_nullifier` (3-0).
  Nuance on the strategy's "nullifiers are no longer persistent identifiers":
  in v4, a uniqueness nullifier is one-time *per action* and `session_id` is the
  **continuity handle** — so for the MVP, a one-time uniqueness proof (to mint
  one-per-human starter credits, keyed by storing the nullifier) plus
  wallet-authenticated sessions is the simplest path. **Alternative:** a single
  **Session** proof bound to the agent's whole access window avoids per-action
  nullifier bookkeeping entirely — it trades proof freshness for implementation
  simplicity; pick at integration.
- **Mini App auth.** `walletAuth()` is the **officially recommended** Mini App
  authentication flow (3-0); Mini Apps run inside World App's webview.
- **Human-in-the-loop.** The HITL package **pauses** a workflow, calls
  `requestHumanAuthorization` for a World ID approval, and **resumes** after
  verification (3-0). The action identifier **defaults to the tool-call id** and
  is **customizable** — bind it to a domain action: `receipt:<nullifier>`,
  `assignment:<note_id>`, `settlement:<batch_id>`, `collateral_release:<enc_id>`.
- **Credentials (future).** `proofOfHuman` is the right MVP anti-Sybil credential;
  `passport` / `identityCheck` exist for country / document-type / minimum-age
  assertions later — keep them out of the first cut unless regulation is central.
- **Payments fallback.** MiniKit pay supports WLD and local stablecoins inside
  World App — the ladder is free per-human starter access first, then
  payment-backed continuation.

### 2.4 World Chain (`docs.world.org/world-chain`)

- **EVM-equivalent**, built on the **OP Stack** — AAC's existing 4/REG registry
  + bb/UltraHonk verifier deploy unchanged.
- **Human-centric primitive: PBH (Priority Blockspace for Humans)** — verified
  humans get priority/allowance in blockspace, which is the on-chain analogue of
  AAC's "scarce access, fairly allocated per human."

## 3. The product: a human-backed clearing copilot

The credible product is **not** "AAC + World ID login." It is a Mini App for
verified humans that **issues and manages proof-carrying commercial receipts
through a human-backed agent**. The user opens it in World App, signs in with
`walletAuth()`, proves uniqueness with World ID to claim one-per-human starter
credits, registers an agent wallet in AgentBook, and lets that agent call
protected AAC endpoints: ingest invoice, identify counterparty, request financing
offers, **generate a balanced-receipt proof**, prepare a settlement batch.

The agent must be **useful before approval**: it may search, summarize, compare,
fetch offers, assemble candidate receipts, and produce *draft* proofs. It may
**not** autonomously commit higher-stakes economic actions — those pause for an
explicit World ID-backed approval bound to the action. That is the clean
separation between *productive agent work* and *human-authorized commitment*.

**What breaks without proof-of-human** (state this in the demo): a bot operator
mints many wallets, farms free proof-gen credits, spams counterparties with RFQs,
opens many "free trial" sessions, or monopolizes scarce financing/settlement
slots. Per-human counters dissolve all of these.

## 4. AgentKit integration — a thin x402 gateway

Do **not** rebuild the AAC backend around AgentKit. Place a thin x402 gateway in
front of the most expensive / abuse-prone AAC endpoints:

```
agent --createAgentkitClient.fetch--> [402 + agentkit challenge]
   --signed retry--> gateway: verifyAgentkitSignature + createAgentBookVerifier
   --> resolve agent wallet -> anonymous human (AgentBook, World Chain)
   --> per-human counter check (free / free-trial / discount)
   --> proxy to AAC service   (or fall back to x402 pay / MiniKit pay)
```

Persist counters + nonces from day one (no `InMemoryAgentKitStorage` in the
demo). For irreversible operations, combine AgentKit with the HITL package: the
agent drafts; only the verified human authorizes, with the approval **bound to**
`receipt:<nullifier>` / `settlement:<batch_id>` rather than a generic tool id.

## 5. ProveKit integration — one narrow circuit

Build **one** narrow application-layer Noir circuit — a **right-sized
EVENT-COMPLETE/1 BalancedVectorReceipt**: a small fixed basis, a small fixed row/
role count, vector sums, range-bounded non-negative coordinates, a nullifier, and
one commitment/leaf hash. That is exactly the circuit shape ProveKit likes.

Discipline that wins the weekend:

- **Isolate it.** A separate package on **Noir beta.19** (ProveKit's pin), NOT
  the beta.14 bb workspace. Port only the AAC math the demo needs. Do not make
  ProveKit the universal proving backend in one weekend — that is toolchain
  spiral, not demo value.
- **Hash.** Default to ProveKit's **Skyscraper** unless a measured reason favors
  Poseidon2; this is independent of the bb workspace's Poseidon2 item.
- **Browser.** Mini App webview builds the witness, fetches the prover key once
  (cache it), proves client-side via the WASM path, posts only proof + public
  inputs to the backend. Budget time for the under-documented browser glue — and
  set an **abort criterion**: if the WASM path overruns (say, a few hours), fall
  back to **server-side proof generation** and still ship the MVP.
- **On-chain (optional polish).** Verify WHIR in the backend; if time remains,
  wrap to Groth16 and verify on World Chain.

## 6. AAC integration map

| World piece | AAC seam |
|---|---|
| `walletAuth()` | Mini App sign-in; binds the session to a wallet |
| World ID uniqueness proof | mints one-per-human starter credits; store the nullifier |
| AgentBook (World Chain) | resolves an agent wallet -> anonymous human; the per-human quota key |
| AgentKit x402 gateway | meters the expensive/abuse-prone AAC endpoints (quote, matching, proof-gen, financing) |
| ProveKit circuit | a right-sized **EVENT-COMPLETE/1** receipt proof, generated client-side |
| AAC 4/REG registry | unchanged; optionally anchors the receipt/transition on World Chain |
| HITL `requestHumanAuthorization` | binds approval to `receipt:<nullifier>` / `settlement:<batch_id>` |
| PBH (World Chain) | on-chain priority for verified humans — mirrors AAC's fair-per-human allocation |

The World-specific logic stays at the **edges**; the AAC core (Pⁿ balance,
Φ_R compilation, the registry's refusals) is untouched.

## 7. Architecture — narrow waist

```
World Mini App
  |- MiniKit walletAuth
  |- World ID uniqueness proof -> one-time starter credits
  |- AgentBook registration (agent wallet)
  |- ProveKit client-side proof generation (webview / WASM)
  '- Human-in-the-loop approval for sensitive actions

Agent Gateway
  |- x402 + AgentKit hooks
  |- per-human trial logic (shared counter)
  |- nonce / replay storage (persistent)
  '- proxy to AAC services

AAC Services
  |- receipt compilation / validation (Phi_R)
  |- quote / matching endpoints
  |- proof verification (WHIR in backend; optional Groth16 on World Chain)
  '- optional World Chain anchoring (4/REG)
```

## 8. The highest-leverage MVP

**One Mini App, one agent, one proof circuit, one approval checkpoint.** The Mini
App: authenticate in World App; prove unique-human + allocate one-per-human
credits; register an agent wallet; show client-side proof generation for a narrow
AAC receipt. The agent: call >=1 x402-protected endpoint via AgentKit and
visibly benefit from the human-backed free-trial. One sensitive action pauses for
World ID-backed approval. That satisfies both "this product breaks without
proof-of-human" and "this is not just a wrapper around AgentKit."

**Do not** prove the full registry-transition model in-browser, replace AAC's
canonical Solidity **4/REG verifier profile** wholesale (a ProveKit receipt
circuit is an optional application-layer addition, never a replacement of the
bb/UltraHonk + 4/REG path), or turn the whole AAC service graph into x402.

## 9. Risks & open questions

- **All Beta, moving fast.** AgentKit is explicitly Beta; ProveKit's pin
  (beta.19) and the AgentBook chain references shift. Pin versions, state which
  you demoed, do not hard-code old examples.
- **AgentBook chain partly unresolved.** Lookup-on-World-Chain (`eip155:480`) is
  only weakly confirmed (2-1) and the "Base mainnet relay" was refuted (0-3); the
  registration transport (direct vs relay, on which chain) is an open question —
  confirm against the live SDK before the demo, do not hard-code it.
- **ProveKit hash choice OPEN.** Skyscraper (default) vs Poseidon2 (examples) —
  decide by measurement; this is *not* the same decision as the bb workspace's
  Poseidon2 migration.
- **ProveKit browser glue is thin.** Budget wrapper work; CLI/mobile are better
  documented than browser.
- **Perf unverified.** Benchmark the receipt circuit with `circuit_stats` /
  `analyze-pkp`; do not quote the strategy's numbers as measured.
- **Noir version split is permanent for now.** beta.14 (bb/UltraHonk workspace,
  the 4/REG path) and beta.19 (the ProveKit receipt circuit) coexist as separate
  packages until a deliberate workspace bump.

## 10. Roadmap escalation (later, not the first cut)

More circuits; recursive settlement proofs on World Chain; larger basis sizes;
multilateral netting (VNET/1); tighter on-chain enforcement (register the
EVENT-COMPLETE/1 verifier in 4/REG); `passport` / `identityCheck` credentials if
regulation becomes central; coSNARK proving for genuinely multiparty events.

---

The pitch, if shipped in this shape: AAC gives private proof-carrying receipts;
ProveKit makes those proofs practical on the client; World ID makes trial access
and scarce allocations fair; AgentKit lets the agent operate safely on behalf of
a real human; human-in-the-loop keeps the last mile of financial commitment under
explicit human control. One trust story, one UX story, one judging story.
