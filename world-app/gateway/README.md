# @aac/world-gateway — AgentKit x402 gateway

A thin x402 gateway that sits in front of the most expensive / abuse-prone AAC
endpoints and meters access **per human** (Design Note 0002 §4). It does **not**
rebuild AAC around AgentKit — it proxies. **Framework-agnostic core** with a **Hono**
example wiring.

## The 402 + agentkit flow (Design Note 0002 §2.2)

```
agent --createAgentkitClient.fetch--> [402 + agentkit challenge]      (core: buildChallenge)
   --signed retry--> parseAgentkitHeader → validateAgentkitMessage →
                     verifyAgentkitSignature → createAgentBookVerifier  (core/agentkit.ts)
   --> resolve agent wallet → anonymous human (AgentBook, World Chain)
   --> consume one-time nonce (replay defence)                         (storage)
   --> per-human shared counter check (free / free-trial / discount)   (core/policy.ts)
   --> proxy to AAC service  (or fall back to x402 / MiniKit pay)       (core/aac-stub.ts)
```

## What is REAL vs stubbed (verified in this scaffold)

| piece | status |
|---|---|
| 402 + `agentkit` challenge response (nonce issue/persist) | **real** — `core/gateway.ts buildChallenge` |
| per-human-per-endpoint SHARED counter (N agents → 1 human's quota) | **real** — `core/policy.ts decideAccess`; the human ref is the counter key |
| free / free-trial / discount policy selection + demo caps | **real** — `core/policy.ts demoPolicies` |
| persistent storage INTERFACE (counters + replay nonces) | **real** — `storage/interface.ts` |
| in-memory storage impl | **real but DEV-ONLY** — `storage/memory.ts` (loud header; no Sybil/replay guarantee) |
| proxy to a stubbed AAC service | **real** — `core/aac-stub.ts` (`StubAacService`; `HttpAacService` sketched) |
| Hono example wiring | **real-shaped, `@ts-nocheck`** — `examples/hono.ts` (hono not installed here) |
| AgentKit SDK calls (`parse`/`validate`/`verifySignature`/`createAgentBookVerifier`) | **STUB — throws** `core/agentkit.ts` (verified helper NAMES, unverified signatures) |

`npm run typecheck` passes over the core (the Hono example is excluded from `tsc`
because hono is an optional peer dep not installed in the scaffold).

## The anti-Sybil core

`core/policy.ts` keys the usage counter on the **AgentBook-resolved `HumanRef`**, not
the agent wallet. Ten agent wallets backed by one human all resolve to the same
`HumanRef`, so they **share one counter** — ten wallets cannot claim ten starter
quotas (Design Note 0002 §2.2, 3-0). The increment is atomic in the storage adapter
so concurrent agents of one human cannot both slip past the cap.

## Persistence is required (no in-memory in the demo)

Design Note 0002 §4: "Persist counters + nonces from day one (no
`InMemoryAgentKitStorage` in the demo)." Implement `GatewayStorage`
(`storage/interface.ts`) against Postgres/Redis with **atomic** `incrementUsage` and
`consumeNonce`. `InMemoryGatewayStorage` is dev-only and says so loudly.

## Known integration TODOs (honest gaps)

1. **The AgentKit SDK is not wired.** `core/agentkit.ts` exposes the four verified
   helper NAMES but every leaf throws. `Gateway.handle` catches the stub throw and
   returns a 501 naming the gap, so a dev run does not silently fake a pass.
2. **Nonce binding.** `Gateway.handle` currently consumes the **raw header** as the
   nonce key. At integration, consume the **parsed nonce** from
   `parseAgentkitHeader` (the SDK surfaces it), and pass it as the `expected.nonce`
   into `validateAgentkitMessage`. The seam is marked in `core/gateway.ts`.
3. **AgentBook chain/transport.** Default `WORLD_CHAIN` (`eip155:480`) — lookup chain
   is only weakly confirmed (2-1) and the registration transport is unresolved. Keep
   it config; confirm against the live SDK.
4. **Header name.** `examples/hono.ts` reads `x-agentkit`; the real header name is
   unverified — confirm against the SDK.

## Use the core (any framework)

```ts
import { Gateway, demoPolicies, StubAacService, InMemoryGatewayStorage,
         createAgentBookVerifier, WORLD_CHAIN } from "@aac/world-gateway";

const gateway = new Gateway({
  config: { agentBookChain: WORLD_CHAIN, policies: demoPolicies(),
            aacServiceBaseUrl: "...", nonceTtlMs: 300000 },
  storage: new InMemoryGatewayStorage(),               // ⚠️ swap for a DB adapter
  agentBook: createAgentBookVerifier({ chain: WORLD_CHAIN }),
  aac: new StubAacService(),                            // ⚠️ swap for HttpAacService
});
const result = await gateway.handle({ endpoint: "quote", resource: "aac:quote",
  agentkitHeader, method: "POST", body });
```

Express / Next.js route handlers reuse the same `gateway.handle(...)` — only the thin
HTTP adapter (like `examples/hono.ts`) changes.
