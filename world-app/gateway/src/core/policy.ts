// Policy engine — the SHARED per-human-per-endpoint quota, the anti-Sybil core.
//
// This is REAL, runnable logic (the counter arithmetic and policy selection). It
// depends only on the GatewayStorage seam, so it works the same against the dev
// in-memory store and a production DB adapter.
//
// Design Note 0002 §2.2 / §4: counters are per-human-per-endpoint and MULTIPLE
// AGENTS BACKED BY THE SAME HUMAN SHARE ONE COUNTER. Ten agent wallets cannot claim
// ten starter quotas because they all resolve (via AgentBook) to the same HumanRef,
// which is the counter key.

import type {
  EndpointPolicy,
  HumanRef,
  PolicyDecision,
  ResolvedAgent,
} from "./types.js";
import type { GatewayStorage } from "../storage/interface.js";

/**
 * Decide access for one resolved agent against one endpoint policy, consuming a
 * unit of the human's shared quota if allowed.
 *
 * - `free`        : always allow, no metering.
 * - `free-trial`  : allow until the human's shared counter for this endpoint hits
 *                   `limit`, then fall back to pay.
 * - `discount`    : same shape; the discount is applied upstream (price), the
 *                   counter caps how many discounted calls the human gets.
 *
 * The increment is the COMMIT: we increment only when we decide `allow`, so a `pay`
 * fallback does not burn quota. Because incrementUsage is atomic in the storage
 * adapter, two of the same human's agents racing here cannot both slip past the cap.
 */
export async function decideAccess(
  agent: ResolvedAgent,
  endpoint: EndpointPolicy,
  storage: GatewayStorage,
): Promise<PolicyDecision> {
  const human: HumanRef = agent.human;

  if (endpoint.policy === "free") {
    // Unmetered, but still record usage for audit/visibility.
    await storage.incrementUsage(human, endpoint.endpoint);
    return { kind: "allow", policy: "free", remaining: Number.POSITIVE_INFINITY };
  }

  // free-trial and discount are both capped against the shared counter.
  const used = await storage.getUsage(human, endpoint.endpoint);
  if (used >= endpoint.limit) {
    return {
      kind: "pay",
      reason: endpoint.policy === "free-trial" ? "trial-exhausted" : "discount-exhausted",
    };
  }

  const next = await storage.incrementUsage(human, endpoint.endpoint);
  // Re-check after the atomic increment in case of a race that pushed us over.
  if (next > endpoint.limit) {
    return {
      kind: "pay",
      reason: endpoint.policy === "free-trial" ? "trial-exhausted" : "discount-exhausted",
    };
  }
  return {
    kind: "allow",
    policy: endpoint.policy,
    remaining: endpoint.limit - next,
  };
}

/**
 * A sane demo starter policy set (Design Note 0002 §2.2): e.g. 3 free quote requests
 * OR 3 free proof-gen attempts OR 1 free financing-run per human-backed agent family,
 * then fall back to x402 / MiniKit pay.
 */
export function demoPolicies(): Record<string, EndpointPolicy> {
  return {
    "quote": { endpoint: "quote", policy: "free-trial", limit: 3 },
    "proof-gen": { endpoint: "proof-gen", policy: "free-trial", limit: 3 },
    "financing-run": { endpoint: "financing-run", policy: "free-trial", limit: 1 },
    // a `discount` example: matching is discounted, capped at 10 discounted calls.
    "matching": { endpoint: "matching", policy: "discount", limit: 10 },
    // a `free` example: health/metadata is always open.
    "metadata": { endpoint: "metadata", policy: "free", limit: 0 },
  };
}
