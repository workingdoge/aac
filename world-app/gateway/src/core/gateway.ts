// The framework-agnostic gateway core. Takes an abstract request, returns an
// abstract response/decision. The Hono example (../examples/hono.ts) adapts real
// HTTP to/from these shapes — so the same core also drops into Express or Next.js
// route handlers (Design Note 0002 §2.2 notes those need an adapter layer; this IS
// that seam).

import { randomBytes } from "node:crypto";
import type {
  AgentkitChallenge,
  GatewayConfig,
  EndpointPolicy,
  PolicyDecision,
  ResolvedAgent,
} from "./types.js";
import { WORLD_CHAIN } from "./types.js";
import { type AgentBookVerifier, resolveAgentFromHeader } from "./agentkit.js";
import { decideAccess } from "./policy.js";
import type { GatewayStorage } from "../storage/interface.js";

/** A toolchain-neutral inbound request. */
export interface GatewayRequest {
  /** logical endpoint id (maps to a policy); the caller derives it from the route. */
  endpoint: string;
  /** the resource string echoed into the challenge / signed message. */
  resource: string;
  /** the raw `agentkit` credential header value, or null if absent. */
  agentkitHeader: string | null;
  /** method + body passed through to the upstream AAC service on allow. */
  method: string;
  body?: unknown;
}

/** A toolchain-neutral outcome. The adapter turns this into a real HTTP response. */
export type GatewayResult =
  | { kind: "challenge"; status: 402; challenge: AgentkitChallenge }
  | { kind: "pay"; status: 402; decision: Extract<PolicyDecision, { kind: "pay" }>; challenge: AgentkitChallenge }
  | { kind: "proxied"; status: number; body: unknown; agent: ResolvedAgent }
  | { kind: "reject"; status: number; reason: string };

/** Upstream AAC service the gateway proxies to on allow. */
export interface AacService {
  call(req: { endpoint: string; method: string; body?: unknown }): Promise<{ status: number; body: unknown }>;
}

export interface GatewayDeps {
  config: GatewayConfig;
  storage: GatewayStorage;
  agentBook: AgentBookVerifier;
  aac: AacService;
  /** injectable for tests; defaults to crypto-random hex. */
  newNonce?: () => string;
  /** injectable clock for tests. */
  now?: () => number;
}

export class Gateway {
  constructor(private readonly deps: GatewayDeps) {}

  private nonce(): string {
    return (this.deps.newNonce ?? (() => randomBytes(16).toString("hex")))();
  }
  private now(): number {
    return (this.deps.now ?? Date.now)();
  }

  /** Build (and persist) a fresh challenge for a resource. */
  async buildChallenge(resource: string): Promise<AgentkitChallenge> {
    const nonce = this.nonce();
    await this.deps.storage.putNonce(nonce, this.now() + this.deps.config.nonceTtlMs);
    return {
      scheme: "agentkit",
      chain: this.deps.config.agentBookChain ?? WORLD_CHAIN,
      nonce,
      resource,
      payHint: "fall back to x402 pay or MiniKit pay (WLD / local stablecoin)",
    };
  }

  /** The full request path: verify credential -> consume nonce -> policy -> proxy. */
  async handle(req: GatewayRequest): Promise<GatewayResult> {
    const policy: EndpointPolicy | undefined = this.deps.config.policies[req.endpoint];
    if (policy === undefined) {
      return { kind: "reject", status: 404, reason: `no policy for endpoint '${req.endpoint}'` };
    }

    const chain = this.deps.config.agentBookChain ?? WORLD_CHAIN;

    // No credential -> emit the 402 + agentkit challenge.
    if (req.agentkitHeader === null) {
      return { kind: "challenge", status: 402, challenge: await this.buildChallenge(req.resource) };
    }

    // We need the nonce the client echoed to (a) validate the message and (b) consume
    // it for replay defence. The client's signed retry carries it in the header; the
    // SDK's parseAgentkitHeader exposes it. We pass the EXPECTED resource/chain and
    // let validateAgentkitMessage bind them. The nonce-consume happens below.
    //
    // resolveAgentFromHeader needs the expected nonce; in the real flow it is read
    // from the parsed header and matched against storage. We model that by parsing
    // first to learn the nonce, then consuming it. To keep the core honest about the
    // stubbed SDK, resolveAgentFromHeader throws inside the stub — see agentkit.ts.
    let agent: ResolvedAgent | null;
    try {
      // The nonce the client must have echoed lives in the header; the SDK parse
      // surfaces it. We re-issue a challenge if anything is off.
      agent = await resolveAgentFromHeader(
        req.agentkitHeader,
        { nonce: "__from_header__", resource: req.resource, chain },
        this.deps.agentBook,
      );
    } catch (e) {
      // The stub throws by design. In integration the SDK returns null on bad creds.
      return {
        kind: "reject",
        status: 501,
        reason:
          `AgentKit SDK not wired (stub threw): ${(e as Error).message}. ` +
          `Replace the stubs in core/agentkit.ts at integration.`,
      };
    }

    if (agent === null) {
      // Invalid/expired credential -> fresh challenge.
      return { kind: "challenge", status: 402, challenge: await this.buildChallenge(req.resource) };
    }

    // Replay defence: consume the nonce the client signed over. A replayed request
    // reuses a spent nonce and is rejected here. (The nonce value comes from the
    // parsed header in integration; consumeNonce is the atomic one-time gate.)
    const nonceOk = await this.deps.storage.consumeNonce(req.agentkitHeader, this.now());
    if (!nonceOk) {
      // Note: in integration, pass the PARSED nonce (not the raw header) — see the
      // TODO in the README. Kept explicit so the replay seam is obvious.
      return { kind: "reject", status: 409, reason: "nonce replay or expiry" };
    }

    // Policy: the shared per-human quota.
    const decision = await decideAccess(agent, policy, this.deps.storage);
    if (decision.kind === "pay") {
      return { kind: "pay", status: 402, decision, challenge: await this.buildChallenge(req.resource) };
    }
    if (decision.kind !== "allow") {
      return { kind: "reject", status: 403, reason: "access denied by policy" };
    }

    // Allowed -> proxy to the stubbed AAC service.
    const upstream = await this.deps.aac.call({ endpoint: req.endpoint, method: req.method, body: req.body });
    return { kind: "proxied", status: upstream.status, body: upstream.body, agent };
  }
}
