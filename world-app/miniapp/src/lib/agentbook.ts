// AgentBook agent-wallet registration seam (client side).
//
// Design Note 0002 §2.2 (CORRECTED + partly unresolved):
//   - AgentBook LOOKUP resolves on World Chain (eip155:480) — WEAKLY confirmed (2-1).
//   - The "gasless relay on Base mainnet" claim was REFUTED (0-3).
//   - The REGISTRATION TRANSPORT (direct submission vs relay, on which chain) is a
//     GENUINE OPEN QUESTION. Do NOT hard-code it. This is config, default World Chain.
//
// ⚠️ The whole registration call is `verify-at-integration`.

/** A CAIP-2 chain id. */
export type ChainId = `eip155:${number}`;

/** World Chain — the DEFAULT lookup/registration chain. Config, not hard-coded. */
export const WORLD_CHAIN: ChainId = "eip155:480";

export interface AgentBookConfig {
  /** Lookup/registration chain. DEFAULT World Chain. Override at integration once
   *  the registration transport is resolved. */
  chain: ChainId;
}

export interface AgentRegistration {
  agentWallet: string;
  chain: ChainId;
  /** opaque receipt/tx ref from the registration transport (shape unknown). */
  registrationRef: string;
}

/**
 * Register an agent wallet in AgentBook so the gateway can resolve it to the
 * verified human (the per-human quota key). STUB — throws until wired.
 *
 * The transport is UNRESOLVED: direct on-chain submission vs a relay, and on which
 * chain. Pass `config.chain` (default World Chain) but treat the actual submission
 * path as TBD at integration.
 */
export async function registerAgentWallet(
  _agentWallet: string,
  config: AgentBookConfig = { chain: WORLD_CHAIN },
): Promise<AgentRegistration> {
  throw new Error(
    `[agentbook] registerAgentWallet on ${config.chain} not wired — the registration ` +
      `transport is UNRESOLVED (direct vs relay, which chain). Verify against the live ` +
      `AgentKit SDK at integration (Design Note 0002 §2.2, §9).`,
  );
}
