// Core types for the AgentKit x402 gateway. Framework-agnostic: no Hono/Express
// imports here. The Hono wiring lives in ../examples/hono.ts.
//
// VERIFICATION STATUS: the AgentKit SDK helper NAMES used below are the verified
// surface (Design Note 0002 §2.2, confirmed 3-0): client `createAgentkitClient`,
// server `parseAgentkitHeader`, `validateAgentkitMessage`, `verifyAgentkitSignature`,
// `createAgentBookVerifier`. Their exact SIGNATURES are NOT verified in this repo —
// every call into the real SDK is marked `verify-at-integration`.

/** A CAIP-2 chain id. AgentBook lookup resolves on World Chain by default. */
export type ChainId = `eip155:${number}`;

/**
 * World Chain. Per Design Note 0002 §2.2 the AgentBook *lookup* resolves here
 * (eip155:480) — but only WEAKLY confirmed (2-1), and the registration transport
 * (direct vs relay, on which chain) is a GENUINE OPEN QUESTION. The "Base mainnet
 * relay" claim was REFUTED (0-3). So this is a configurable DEFAULT, never hard-coded.
 */
export const WORLD_CHAIN: ChainId = "eip155:480";

/** AgentKit access policies that ship in the SDK (Design Note 0002 §2.2). */
export type AccessPolicy = "free" | "free-trial" | "discount";

/** The decision the policy engine returns for one request. */
export type PolicyDecision =
  | { kind: "allow"; policy: AccessPolicy; remaining: number }
  | { kind: "pay"; reason: "trial-exhausted" | "discount-exhausted" | "no-free-tier" }
  | { kind: "challenge" } // no/invalid agentkit credential -> emit the 402
  | { kind: "reject"; reason: string };

/**
 * The anonymous human an agent wallet resolves to via AgentBook. This id is the
 * per-human quota KEY — the anti-Sybil core: many agent wallets backed by one human
 * share ONE counter (Design Note 0002 §2.2, 3-0). It is opaque/anonymous: we never
 * learn the person, only that two agents map to the same one.
 */
export type HumanRef = string & { readonly __brand: "HumanRef" };

/** A resolved, signature-verified agent identity for one request. */
export interface ResolvedAgent {
  /** the agent wallet address that signed the x402/CAIP-122 challenge */
  agentWallet: string;
  /** the anonymous human this wallet is backed by (AgentBook lookup) */
  human: HumanRef;
  /** the chain the AgentBook lookup resolved on (for audit; default WORLD_CHAIN) */
  resolvedOnChain: ChainId;
}

/** Per-endpoint policy configuration. */
export interface EndpointPolicy {
  /** logical endpoint id the counter is keyed by (NOT the raw URL). */
  endpoint: string;
  /** which policy applies and the per-human cap. `free` ignores `limit`. */
  policy: AccessPolicy;
  /** max uses per human per endpoint for free-trial / discount. */
  limit: number;
}

/** What the gateway needs to build a 402 challenge body. */
export interface AgentkitChallenge {
  /** the x402 extension name. */
  scheme: "agentkit";
  /** CAIP-2 chain the client should resolve/sign against. */
  chain: ChainId;
  /** a server nonce the client must echo in its signed retry (replay defence). */
  nonce: string;
  /** the logical resource being gated. */
  resource: string;
  /** human-readable hint for the fallback (x402 pay / MiniKit pay). */
  payHint?: string;
}

/** The parsed inbound agentkit credential (from the request header). */
export interface ParsedAgentkitHeader {
  scheme: "agentkit";
  agentWallet: string;
  /** the signature over the CAIP-122 message. */
  signature: string;
  /** the nonce echoed back from the challenge. */
  nonce: string;
  /** the raw CAIP-122 message that was signed. */
  message: string;
}

/** Configuration for the whole gateway. */
export interface GatewayConfig {
  /**
   * Registration / lookup chain. DEFAULT World Chain. Config, not hard-coded —
   * the registration transport is unresolved (Design Note 0002 §2.2, §9).
   */
  agentBookChain: ChainId;
  /** per-endpoint policies, keyed by logical endpoint id. */
  policies: Record<string, EndpointPolicy>;
  /** upstream AAC service base URL the gateway proxies to. */
  aacServiceBaseUrl: string;
  /** nonce TTL in ms (replay window). */
  nonceTtlMs: number;
}
