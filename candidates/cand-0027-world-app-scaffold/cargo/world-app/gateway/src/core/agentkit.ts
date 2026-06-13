// AgentKit SDK adapter — wraps the VERIFIED server-side helper names behind a small
// interface so the rest of the gateway does not import the Beta SDK directly. This
// is the ONE file that touches the real SDK; everything it returns is typed locally.
//
// Verified helper NAMES (Design Note 0002 §2.2, confirmed 3-0):
//   server: parseAgentkitHeader, validateAgentkitMessage, verifyAgentkitSignature,
//           createAgentBookVerifier
//   client: createAgentkitClient  (used in the Mini App, not here)
//
// ⚠️ Every call below is `verify-at-integration`: the helper SIGNATURES are NOT
// verified in this repo. The real import is left commented; the live implementation
// is a stub that THROWS so nothing silently fakes a pass.

import type {
  ChainId,
  HumanRef,
  ParsedAgentkitHeader,
  ResolvedAgent,
} from "./types.js";

// At integration, replace these stubs with the real SDK, e.g.:
//   import {
//     parseAgentkitHeader as sdkParse,
//     validateAgentkitMessage as sdkValidate,
//     verifyAgentkitSignature as sdkVerify,
//     createAgentBookVerifier as sdkAgentBook,
//   } from "@worldcoin/agentkit"; // package name UNVERIFIED — confirm at integration

const UNVERIFIED = (name: string): never => {
  throw new Error(
    `[agentkit] ${name} is a stub. Wire the real AgentKit SDK helper at ` +
      `integration (Design Note 0002 §2.2). This throws on purpose so nothing ` +
      `fakes a verification pass.`,
  );
};

/** The AgentBook verifier handle, created once at startup. */
export interface AgentBookVerifier {
  /**
   * Resolve a verified agent wallet to the anonymous human it is backed by.
   * Returns null if the wallet is not registered. The chain is the lookup chain
   * (default World Chain; see types.ts — the transport is unresolved).
   */
  resolveHuman(agentWallet: string, chain: ChainId): Promise<HumanRef | null>;
}

/**
 * createAgentBookVerifier — VERIFIED NAME. Stubbed here.
 * At integration: `return sdkAgentBook({ chain })` (signature unverified).
 */
export function createAgentBookVerifier(_opts: { chain: ChainId }): AgentBookVerifier {
  return {
    async resolveHuman(_agentWallet: string, _chain: ChainId): Promise<HumanRef | null> {
      return UNVERIFIED("createAgentBookVerifier().resolveHuman");
    },
  };
}

/**
 * parseAgentkitHeader — VERIFIED NAME. Stubbed here.
 * Parses the inbound `agentkit` credential header into its fields. At integration:
 * `return sdkParse(headerValue)`.
 */
export function parseAgentkitHeader(_headerValue: string | null): ParsedAgentkitHeader | null {
  // A real impl returns null when the header is absent/malformed -> the gateway
  // then emits the 402 challenge. We THROW here to avoid a silent false pass.
  return UNVERIFIED("parseAgentkitHeader");
}

/**
 * validateAgentkitMessage — VERIFIED NAME. Stubbed here.
 * Checks the CAIP-122 message is well-formed and binds the expected nonce/resource.
 */
export function validateAgentkitMessage(
  _parsed: ParsedAgentkitHeader,
  _expected: { nonce: string; resource: string; chain: ChainId },
): boolean {
  return UNVERIFIED("validateAgentkitMessage");
}

/**
 * verifyAgentkitSignature — VERIFIED NAME. Stubbed here.
 * Verifies the x402 / CAIP-122 signature over the message for the claimed wallet.
 */
export function verifyAgentkitSignature(_parsed: ParsedAgentkitHeader): Promise<boolean> {
  return Promise.resolve(UNVERIFIED("verifyAgentkitSignature"));
}

/**
 * The composed verify step the gateway calls: parse -> validate -> verify sig ->
 * resolve human. Returns a ResolvedAgent on success, or null to signal "emit 402".
 *
 * NOTE: this is the orchestration the gateway actually depends on; it is real code.
 * The four leaf calls are the stubs above — swap them for the SDK and this function
 * works unchanged.
 */
export async function resolveAgentFromHeader(
  headerValue: string | null,
  expected: { nonce: string; resource: string; chain: ChainId },
  agentBook: AgentBookVerifier,
): Promise<ResolvedAgent | null> {
  const parsed = parseAgentkitHeader(headerValue);
  if (parsed === null) return null;

  if (!validateAgentkitMessage(parsed, expected)) return null;
  if (!(await verifyAgentkitSignature(parsed))) return null;

  const human = await agentBook.resolveHuman(parsed.agentWallet, expected.chain);
  if (human === null) return null;

  return {
    agentWallet: parsed.agentWallet,
    human,
    resolvedOnChain: expected.chain,
  };
}
