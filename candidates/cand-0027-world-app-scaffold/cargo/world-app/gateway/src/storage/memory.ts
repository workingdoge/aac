// ⚠️ DEV-ONLY in-memory storage. DO NOT USE IN THE DEMO OR PRODUCTION.
//
// Design Note 0002 §4 is explicit: "Persist counters + nonces from day one (no
// `InMemoryAgentKitStorage` in the demo)." This exists ONLY so the gateway runs on a
// laptop during development. It loses all state on restart, does not survive multiple
// processes, and therefore provides NO real anti-Sybil or replay guarantee.
//
// Production: implement GatewayStorage against Postgres/Redis/etc. with the
// increment + nonce-consume done ATOMICALLY (a transaction or an atomic op), because
// concurrent agents of one human race on the shared counter.

import type { GatewayStorage } from "./interface.js";
import type { HumanRef } from "../core/types.js";

/** DEV-ONLY. See file header. */
export class InMemoryGatewayStorage implements GatewayStorage {
  private usage = new Map<string, number>();
  private nonces = new Map<string, { expiresAtMs: number; consumed: boolean }>();

  constructor() {
    // Fail closed in production: this impl gives NO real anti-Sybil/replay guarantee
    // (state is per-process, lost on restart, and incrementUsage races), so it must
    // never back a live deployment. Design Note 0002 §4 forbids it in the demo too.
    const env =
      (typeof process !== "undefined" && process.env && process.env.NODE_ENV) || "";
    if (env === "production") {
      throw new Error(
        "InMemoryGatewayStorage is DEV-ONLY (Design Note 0002 §4): refusing to run with " +
          "NODE_ENV=production. Provide a persistent GatewayStorage (Postgres/Redis) with " +
          "atomic increment + nonce-consume.",
      );
    }
  }

  private key(human: HumanRef, endpoint: string): string {
    return `${human}::${endpoint}`;
  }

  async getUsage(human: HumanRef, endpoint: string): Promise<number> {
    return this.usage.get(this.key(human, endpoint)) ?? 0;
  }

  async incrementUsage(human: HumanRef, endpoint: string): Promise<number> {
    const k = this.key(human, endpoint);
    const next = (this.usage.get(k) ?? 0) + 1;
    this.usage.set(k, next);
    return next;
  }

  async putNonce(nonce: string, expiresAtMs: number): Promise<void> {
    this.nonces.set(nonce, { expiresAtMs, consumed: false });
  }

  async consumeNonce(nonce: string, nowMs: number): Promise<boolean> {
    const rec = this.nonces.get(nonce);
    if (rec === undefined) return false; // unknown nonce
    if (rec.consumed) return false; // replay
    if (rec.expiresAtMs < nowMs) return false; // expired
    rec.consumed = true;
    return true;
  }

  async sweepExpiredNonces(nowMs: number): Promise<number> {
    let dropped = 0;
    for (const [nonce, rec] of this.nonces) {
      if (rec.expiresAtMs < nowMs) {
        this.nonces.delete(nonce);
        dropped++;
      }
    }
    return dropped;
  }
}
