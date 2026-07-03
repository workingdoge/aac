import type { FundraisePacket, VerifyOptions } from "../../fundraise-runtime/src/index.d.ts";

export declare const AUTHORIZER_RECEIPT_SCHEMA = "aac.fundraise-authorizer.receipt.v1";
export declare const SETTLEMENT_SIGNING_REQUEST_SCHEMA =
  "aac.fundraise-authorizer.settlement-signing-request.v1";
export declare const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";
export declare const DEFAULT_PROOF_VERIFIER_REF = "provekit-or-cre-verifier:pending";
export declare const DEFAULT_ADMISSIBILITY_REF = "cre-admissibility:demo";
export declare const DEFAULT_RECIPIENT_OVERRIDES: Readonly<Record<string, string>>;

export interface AuthorizerPolicy {
  policy_id: string;
  authorizer_id: string;
  settlement_contract: string;
  chain_id: number;
  token_contract: string;
  round_id: string;
  round_id_hash: string;
  verifier_profile: string;
  proof_verifier_ref: string;
  admissibility_ref: string;
}

export interface SettlementSigningRequest {
  schema: typeof SETTLEMENT_SIGNING_REQUEST_SCHEMA;
  policy_id: string;
  authorizer_id: string;
  verifier_profile: string;
  proof_verifier_ref: string;
  admissibility_ref: string;
  chain_id: number;
  settlement_contract: string;
  signing_domain: "FundraiseMintSettlement.settlementDigest(auth)";
  runtime_round_id: string;
  contract_authorization: {
    round_id_hash: string;
    token_contract: string;
    runtime_authorization_digest: string;
    runtime_mint_recipient_set_commitment: string;
    issued_unit_total: number;
    recipients: Array<{ account: string; amount: number }>;
  };
  settlement_digest_witness: string;
  request_digest: string;
}

export type AuthorizerReceipt =
  | {
      schema: typeof AUTHORIZER_RECEIPT_SCHEMA;
      accepted: true;
      reason: "accepted";
      policy: AuthorizerPolicy;
      packet_commitment: string;
      request: SettlementSigningRequest;
      receipt_digest: string;
    }
  | {
      schema: typeof AUTHORIZER_RECEIPT_SCHEMA;
      accepted: false;
      reason: string;
      policy: AuthorizerPolicy | null;
      packet_commitment: string | null;
      request: null;
      detail: Record<string, unknown>;
      receipt_digest: string;
    };

export interface AuthorizerInput {
  packet: FundraisePacket;
  policy?: Partial<AuthorizerPolicy>;
  recipient_overrides?: Record<string, string>;
  verify_options?: VerifyOptions;
}

export declare class FundraiseAuthorizerError extends Error {
  readonly reason: string;
  readonly detail: Record<string, unknown>;
  constructor(reason: string, message?: string, detail?: Record<string, unknown>);
}

export declare function canonical(value: unknown): string;
export declare function digestHex(label: string, ...parts: unknown[]): string;
export declare function createAuthorizerPolicy(overrides?: Partial<AuthorizerPolicy>): AuthorizerPolicy;
export declare function buildSettlementSigningRequest(input: AuthorizerInput): SettlementSigningRequest;
export declare function authorizeFundraisePacket(input: AuthorizerInput): AuthorizerReceipt;
export declare function verifyAuthorizerReceipt(
  receipt: AuthorizerReceipt | unknown,
):
  | { accepted: true; reason: "accepted"; request: SettlementSigningRequest }
  | { accepted: false; reason: string };
export declare function withEvmRecipients(
  authorization: unknown,
  recipientOverrides?: Record<string, string>,
): unknown;
export declare function settlementDigestWitness(request: SettlementSigningRequest): string;
export declare function signingRequestDigest(request: SettlementSigningRequest): string;
