// Persistent storage interface — counters + replay nonces.
//
// Design Note 0002 §2.2 / §4: `InMemoryAgentKitStorage` is DEV-ONLY; production MUST
// persist usage counters AND replay nonces ("replay protection is part of the
// fairness story"). This interface is what a DB-backed adapter implements; the
// in-memory impl (./memory.ts) is clearly marked dev-only.

import type { HumanRef } from "../core/types.js";

/**
 * The fairness/replay storage seam. Two concerns:
 *  - per-human-per-endpoint usage counters (the SHARED quota: N agents -> 1 human)
 *  - one-time nonces (replay defence on the signed x402 retry)
 *
 * All methods are async so a real adapter can be a database. The in-memory impl
 * satisfies them synchronously under the hood.
 */
export interface GatewayStorage {
  // --- per-human-per-endpoint usage counters ---

  /** Current usage count for (human, endpoint). 0 if never seen. */
  getUsage(human: HumanRef, endpoint: string): Promise<number>;

  /**
   * Atomically increment and return the NEW count for (human, endpoint).
   * Atomicity matters: two agents of the same human may hit the gateway
   * concurrently and MUST share the one counter without a lost update.
   */
  incrementUsage(human: HumanRef, endpoint: string): Promise<number>;

  // --- one-time replay nonces ---

  /** Record a freshly issued challenge nonce with an expiry (epoch ms). */
  putNonce(nonce: string, expiresAtMs: number): Promise<void>;

  /**
   * Atomically consume a nonce: returns true iff the nonce existed, was unexpired,
   * and had not been consumed before — and marks it consumed. A replayed signed
   * request reuses a nonce and MUST get false here.
   */
  consumeNonce(nonce: string, nowMs: number): Promise<boolean>;

  /** Optional housekeeping: drop expired nonces. */
  sweepExpiredNonces?(nowMs: number): Promise<number>;
}
