// Public barrel for the framework-agnostic gateway core. Import from here; the
// Hono wiring (examples/hono.ts) is one possible adapter.

export * from "./core/types.js";
export * from "./core/agentkit.js";
export * from "./core/policy.js";
export * from "./core/gateway.js";
export * from "./core/aac-stub.js";
export * from "./storage/interface.js";
export { InMemoryGatewayStorage } from "./storage/memory.js"; // ⚠️ DEV-ONLY
