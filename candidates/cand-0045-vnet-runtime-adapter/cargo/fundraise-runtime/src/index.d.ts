export declare const SCHEMA = "aac.fundraise-demo.conformance.v1";
export declare const SETTLEMENT_ASSET = "USDC:arc-testnet:atomic";
export declare const ISSUED_UNIT = "SAFE:issuer:series-a:unit";

export type VerificationResult =
  | { accepted: true; reason: "accepted"; authorization: AuthorizedMint }
  | { accepted: false; reason: string };

export interface RoundPolicy {
  round_id: string;
  issuer_name: string;
  settlement_asset_type_id: string;
  issued_unit_type_id: string;
  price_numerator: number;
  price_denominator: number;
  max_settlement_amount: number;
  max_issued_units: number;
  token_contract: string;
  settlement_chain: string;
  vault_or_contract: string;
  transfer_policy_hash: string;
  admissibility_policy_hash: string;
  settlement_adapter_hash: string;
}

export interface Subscription {
  subscription_id: string;
  investor_id: string;
  mint_recipient: string;
  settlement_ref: string;
  settlement_amount: number;
  issued_units: number;
  admissibility_ref: string;
  subscription_nullifier: string;
}

export interface SettlementReport {
  schema: "aac.fundraise-demo.settlement-report.v1";
  adapter_hash: string;
  accepted: Array<{
    settlement_ref: string;
    investor_id: string;
    asset_type_id: string;
    amount: number;
  }>;
}

export interface BridgeSettlement {
  schema: "aac.fundraise-demo.bridge-settlement.v1";
  settlement_chain: string;
  vault_or_contract: string;
  asset_type_id: string;
  accepted: Array<{
    subscription_id: string;
    investor_id: string;
    settlement_ref: string;
    deposit_ref: string;
    amount: number;
  }>;
}

export interface AdmissibilityReport {
  schema: "aac.fundraise-demo.admissibility-report.v1";
  policy_hash: string;
  accepted: Array<{
    admissibility_ref: string;
    investor_id: string;
    accepted: boolean;
  }>;
}

export interface MintAuthorization {
  schema: "aac.fundraise-demo.mint-authorization.v1";
  round_id: string;
  token_contract: string;
  issued_unit_total: number;
  mint_recipient_set_commitment: string;
  recipients: Array<{
    investor_id: string;
    recipient: string;
    issued_units: number;
  }>;
}

export interface FundraisePacket {
  round_policy: RoundPolicy;
  subscriptions: Subscription[];
  bcc_agreements: Array<{
    schema: "aac.fundraise-demo.bcc-agreement.v1";
    subscription_id: string;
    certificate: any;
  }>;
  bridge_settlement: BridgeSettlement;
  settlement_report: SettlementReport;
  admissibility_report: AdmissibilityReport;
  vnet_link: any;
  mint_authorization: MintAuthorization;
  public_inputs: Record<string, unknown>;
}

export interface BccSignatureVerifierInput {
  certificate: any;
  record: any;
  signature: any;
  typed_data: any;
  transcript_hash: string;
}

export interface BccCancellationVerifierInput {
  certificate: any;
  cancellation_opening: any;
  payload: any;
}

export interface AuthorizedMint {
  schema: "aac.fundraise-runtime.authorized-mint.v1";
  round_id: string;
  token_contract: string;
  issued_unit_total: number;
  mint_recipient_set_commitment: string;
  authorization_digest: string;
  recipients: MintAuthorization["recipients"];
}

export interface VerifyOptions {
  /**
   * Optional deployment verifier for VNET/1. If omitted, the runtime uses the
   * dependency-free JS reference verifier for the landed VNET-BN254-G1/1
   * transition-link fixture shape.
   */
  verifyVnetLink?: (vnetLink: any) => { accepted: boolean; reason: string };
  seenBccFinalityTags?: Set<string>;
  seen_bcc_finality_tags?: string[];
  verifyBccSignature?: (input: BccSignatureVerifierInput) => boolean | { accepted: boolean; reason?: string };
  verify_bcc_signature?: (input: BccSignatureVerifierInput) => boolean | { accepted: boolean; reason?: string };
  verifyBccCancellation?: (input: BccCancellationVerifierInput) => boolean | { accepted: boolean; reason?: string };
  verify_bcc_cancellation?: (input: BccCancellationVerifierInput) => boolean | { accepted: boolean; reason?: string };
  bccSignatureDomain?: Record<string, unknown>;
  bcc_signature_domain?: Record<string, unknown>;
}

export declare class FundraiseVerificationError extends Error {
  readonly reason: string;
  constructor(reason: string, message?: string);
}

export declare function canonical(value: unknown): string;
export declare function digestHex(label: string, ...parts: unknown[]): string;
export declare function createRoundPolicy(overrides?: Partial<RoundPolicy>): RoundPolicy;
export declare function createSubscription(input: Subscription): Subscription;
export declare function buildSettlementReport(policy: RoundPolicy, subscriptions: Subscription[]): SettlementReport;
export declare function buildBridgeSettlement(policy: RoundPolicy, subscriptions: Subscription[]): BridgeSettlement;
export declare function buildAdmissibilityReport(policy: RoundPolicy, subscriptions: Subscription[]): AdmissibilityReport;
export declare function buildMintAuthorization(policy: RoundPolicy, subscriptions: Subscription[]): MintAuthorization;
export declare function vnetPublic(vnetLink: any): Record<string, unknown>;
export declare function bccPublic(agreement: FundraisePacket["bcc_agreements"][number]): Record<string, unknown>;
export declare function buildBccAgreements(
  policy: RoundPolicy,
  subscriptions: Subscription[],
  vnetLink: any,
): FundraisePacket["bcc_agreements"];
export declare function vnetAmountTotals(vnetLink: any): [number[], number[]];
export declare function buildPublicInputs(
  policy: RoundPolicy,
  subscriptions: Subscription[],
  vnetLink: any,
  mintAuthorization: MintAuthorization,
  bccAgreements: FundraisePacket["bcc_agreements"],
  bridgeSettlement: BridgeSettlement,
): Record<string, unknown>;
export declare function buildFundraisePacket(input: {
  policy?: RoundPolicy;
  subscriptions: Subscription[];
  vnetLink: any;
  bccAgreements?: FundraisePacket["bcc_agreements"];
  bridgeSettlement?: BridgeSettlement;
  settlementReport?: SettlementReport;
  admissibilityReport?: AdmissibilityReport;
  mintAuthorization?: MintAuthorization;
}): FundraisePacket;
export declare function verifyFundraisePacket(packet: FundraisePacket, opts?: VerifyOptions): VerificationResult;
export declare function authorizeMint(packet: FundraisePacket): AuthorizedMint;
