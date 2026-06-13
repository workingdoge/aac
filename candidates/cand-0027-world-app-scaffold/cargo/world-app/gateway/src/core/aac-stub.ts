// A STUBBED AAC service. Stands in for the real AAC backend (quote / matching /
// proof-gen / financing endpoints) the gateway sits in front of (Design Note 0002
// §4: "a thin x402 gateway in front of the most expensive / abuse-prone AAC
// endpoints"). The gateway does NOT rebuild AAC around AgentKit — it proxies.
//
// This is honest-stub: it echoes a deterministic body so the gateway path is
// end-to-end runnable in dev. Replace `StubAacService` with an HTTP proxy to the
// real `aacServiceBaseUrl` at integration.

import type { AacService } from "./gateway.js";

/** Dev stub. Returns canned, deterministic responses per endpoint. */
export class StubAacService implements AacService {
  async call(req: { endpoint: string; method: string; body?: unknown }): Promise<{ status: number; body: unknown }> {
    switch (req.endpoint) {
      case "quote":
        return { status: 200, body: { kind: "quote", price_hint: "stubbed", echo: req.body ?? null } };
      case "matching":
        return { status: 200, body: { kind: "matching", candidates: [], note: "stubbed matcher" } };
      case "proof-gen":
        // The real proof-gen is the ProveKit flow (client-side); this server path is
        // the SERVER-SIDE fallback the abort criterion points to (Design Note 0002 §5).
        return { status: 200, body: { kind: "proof-gen", mode: "server-fallback", proof: "stub" } };
      case "financing-run":
        return { status: 200, body: { kind: "financing-run", offers: [], note: "stubbed financing" } };
      case "metadata":
        return { status: 200, body: { kind: "metadata", service: "aac", version: "stub" } };
      default:
        return { status: 404, body: { error: `unknown AAC endpoint '${req.endpoint}'` } };
    }
  }
}

/**
 * The real adapter at integration: forward to `aacServiceBaseUrl`. Sketched, not
 * wired, so the dev path stays self-contained.
 */
export class HttpAacService implements AacService {
  constructor(private readonly baseUrl: string) {}
  async call(req: { endpoint: string; method: string; body?: unknown }): Promise<{ status: number; body: unknown }> {
    const res = await fetch(`${this.baseUrl}/${req.endpoint}`, {
      method: req.method,
      headers: { "content-type": "application/json" },
      body: req.body === undefined ? undefined : JSON.stringify(req.body),
    });
    const body = await res.json().catch(() => null);
    return { status: res.status, body };
  }
}
