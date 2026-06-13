// Hono example wiring. Hono / `@x402/hono` is the MAINTAINED AgentKit example
// (Design Note 0002 §2.2), so it is the reference adapter here. Express / Next.js
// route handlers can reuse the SAME framework-agnostic core (../core/gateway.ts) —
// only this thin adapter changes.
//
// This file is NOT typechecked in the agent build (hono is not installed; we do not
// block on npm install). It is the integration template. The import is real; run
// `npm i hono` then `tsc` to typecheck it.
//
// @ts-nocheck -- hono is an optional peer dep; this is a template, not built here.

import { Hono } from "hono";

import { Gateway } from "../core/gateway.js";
import { createAgentBookVerifier } from "../core/agentkit.js";
import { StubAacService } from "../core/aac-stub.js";
import { InMemoryGatewayStorage } from "../storage/memory.js"; // ⚠️ DEV-ONLY
import { demoPolicies } from "../core/policy.js";
import { WORLD_CHAIN, type GatewayConfig } from "../core/types.js";

// ---- compose the gateway ----------------------------------------------------

const config: GatewayConfig = {
  // DEFAULT World Chain; the registration transport is unresolved — make it config.
  agentBookChain: WORLD_CHAIN,
  policies: demoPolicies(),
  aacServiceBaseUrl: process.env.AAC_SERVICE_URL ?? "http://localhost:8788",
  nonceTtlMs: 5 * 60_000, // 5 minutes
};

const gateway = new Gateway({
  config,
  // ⚠️ swap InMemoryGatewayStorage for a DB-backed adapter before the demo.
  storage: new InMemoryGatewayStorage(),
  agentBook: createAgentBookVerifier({ chain: config.agentBookChain }),
  aac: new StubAacService(), // swap for HttpAacService(config.aacServiceBaseUrl)
});

// ---- HTTP adapter -----------------------------------------------------------

const app = new Hono();

// One protected route family. The logical `endpoint` (the counter key) is the path
// segment, NOT the raw URL — so query strings cannot fork the quota.
app.all("/aac/:endpoint", async (c) => {
  const endpoint = c.req.param("endpoint");
  const result = await gateway.handle({
    endpoint,
    resource: `aac:${endpoint}`,
    agentkitHeader: c.req.header("x-agentkit") ?? null, // header name verify-at-integration
    method: c.req.method,
    body: c.req.method === "GET" ? undefined : await c.req.json().catch(() => undefined),
  });

  switch (result.kind) {
    case "challenge":
      // 402 + the agentkit extension challenge the client's createAgentkitClient
      // inspects and signs.
      return c.json({ scheme: "agentkit", challenge: result.challenge }, 402);
    case "pay":
      return c.json(
        { scheme: "agentkit", reason: result.decision.reason, challenge: result.challenge },
        402,
      );
    case "proxied":
      return c.json(result.body as object, result.status as 200);
    case "reject":
      return c.json({ error: result.reason }, result.status as 400);
  }
});

export default app;

// Run: `npm i hono @hono/node-server && node --loader ts-node/esm src/examples/serve.ts`
// (a `serve.ts` that calls @hono/node-server is left to integration.)
