// AgentKit CLIENT seam — the agent's authenticated fetch into the gateway.
//
// Verified surface (Design Note 0002 §2.2, 3-0): the client helper is
// `createAgentkitClient(...).fetch(...)`. It inspects a 402 + agentkit challenge,
// signs the x402 / CAIP-122 challenge, and retries. STUB until the SDK is wired.

import type { ChainId } from "./agentbook.js";
import { WORLD_CHAIN } from "./agentbook.js";

export interface AgentkitClient {
  /**
   * Drop-in fetch that handles the 402 + agentkit challenge transparently: on a
   * 402 it signs the challenge and retries once. Same shape as the standard fetch.
   */
  fetch(input: string, init?: RequestInit): Promise<Response>;
}

export interface AgentkitClientConfig {
  /** the agent wallet signer (shape per the SDK; unverified). */
  signer: unknown;
  /** chain the challenge resolves against. DEFAULT World Chain. */
  chain: ChainId;
}

/**
 * createAgentkitClient — VERIFIED NAME. STUB.
 * At integration: `return sdkCreateAgentkitClient({ signer, chain })`.
 */
export function createAgentkitClient(
  config: AgentkitClientConfig = { signer: null, chain: WORLD_CHAIN },
): AgentkitClient {
  return {
    async fetch(_input: string, _init?: RequestInit): Promise<Response> {
      throw new Error(
        `[agentkit-client] createAgentkitClient({chain:${config.chain}}).fetch not wired ` +
          `— import the AgentKit client SDK at integration (verify-at-integration).`,
      );
    },
  };
}
