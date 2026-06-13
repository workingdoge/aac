// World ID + Mini App auth seam.
//
// Verified surface (Design Note 0002 §2.3):
//   - backend verify endpoint: POST /api/v4/verify/{rp_id}   (3-0)
//   - Mini App auth: walletAuth()  (officially recommended, 3-0)
//   - uniqueness proof -> one-time nullifier per action (2-1)
//   - HITL: requestHumanAuthorization, action id defaults to tool-call id and is
//     customizable -> bind to receipt:<nullifier> / settlement:<batch_id> (3-0)
//
// ⚠️ Every MiniKit / World ID SDK call is `verify-at-integration`. The package
// import is left as a typed shim so this file compiles WITHOUT the SDK installed;
// swap the shim for the real MiniKit import at integration.

// ---- typed shim for the MiniKit SDK (replace at integration) -----------------
// At integration: `import { MiniKit } from "@worldcoin/minikit-js";`
// The shapes below are the MINIMUM this app uses; confirm against the live SDK.

export interface WalletAuthResult {
  address: string;
  // the SIWE-style payload MiniKit returns; opaque to us, verified server-side.
  payload: unknown;
}

export interface UniquenessProof {
  /** the one-time nullifier for this action — the per-human credit key. */
  nullifier_hash: string;
  merkle_root: string;
  proof: string;
  verification_level: "orb" | "device";
}

/** The verified World ID v4 backend verify route. */
export const WORLD_ID_VERIFY_ROUTE = (rpId: string) => `/api/v4/verify/${rpId}`;

/**
 * walletAuth() — the officially recommended Mini App sign-in. Binds the session to
 * a wallet (Design Note 0002 §2.3). STUB: throws until MiniKit is wired.
 */
export async function walletAuth(): Promise<WalletAuthResult> {
  throw new Error(
    "[worldid] walletAuth() not wired — import MiniKit and call its walletAuth at " +
      "integration (verify-at-integration, Design Note 0002 §2.3).",
  );
}

/**
 * Request a World ID UNIQUENESS proof for an action. Returns a one-time nullifier
 * (one per action). The MVP mints one-per-human starter credits keyed by storing
 * this nullifier (Design Note 0002 §2.3, §6). STUB.
 *
 * Alternative noted in the design: a single SESSION proof bound to the agent's whole
 * access window avoids per-action nullifier bookkeeping — pick at integration.
 */
export async function proveUniqueness(_action: string): Promise<UniquenessProof> {
  throw new Error(
    "[worldid] proveUniqueness() not wired — MiniKit verify command (verify-at-integration).",
  );
}

/**
 * HITL: pause the workflow for an explicit World ID-backed human approval, then
 * resume. The action id MUST be bound to a DOMAIN action, not a generic tool id —
 * `receipt:<nullifier>` or `settlement:<batch_id>` (Design Note 0002 §2.3, §4).
 *
 * `requestHumanAuthorization` is the VERIFIED HITL function name. STUB.
 */
export async function requestHumanAuthorization(actionToken: DomainActionToken): Promise<HitlApproval> {
  // At integration: call the HITL package's requestHumanAuthorization with
  //   { action: actionToken.value }  (defaults to tool-call id; we OVERRIDE it).
  throw new Error(
    `[worldid] requestHumanAuthorization('${actionToken.value}') not wired ` +
      `(verify-at-integration, Design Note 0002 §2.3).`,
  );
}

// ---- domain action tokens (the HITL binding) --------------------------------

/** A typed approval token bound to a specific irreversible AAC action. */
export interface DomainActionToken {
  kind: "receipt" | "settlement" | "assignment" | "collateral_release";
  value: string; // e.g. "receipt:0xabc...", "settlement:batch-42"
}

export function receiptActionToken(nullifier: string): DomainActionToken {
  return { kind: "receipt", value: `receipt:${nullifier}` };
}
export function settlementActionToken(batchId: string): DomainActionToken {
  return { kind: "settlement", value: `settlement:${batchId}` };
}

export interface HitlApproval {
  approved: boolean;
  /** the World ID proof backing the approval, verified server-side. */
  proof: unknown;
  actionToken: DomainActionToken;
}
