import type { AuthorizerPolicy, AuthorizerReceipt } from "../../fundraise-authorizer/src/index.d.ts";
import type { FundraisePacket, VerifyOptions } from "../../fundraise-runtime/src/index.d.ts";

export declare const WORKFLOW_RECEIPT_SCHEMA = "aac.fundraise-workflow.receipt.v1";
export declare const VERIFIER_RECEIPT_SCHEMA = "aac.fundraise-workflow.verifier-receipt.v1";
export declare const SETTLEMENT_ACTION_SCHEMA = "aac.fundraise-workflow.settlement-action.v1";
export declare const DEFAULT_WORKFLOW_ID = "aac-fundraise-authorizer-workflow";
export declare const DEFAULT_WORKFLOW_ENGINE = "cre-sdk-wrapper:pending";
export declare const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";

export interface WorkflowPolicy {
  workflow_id: string;
  workflow_engine: string;
  verifier_profile: string;
  accepted_proof_systems: string[];
  require_live_proof: boolean;
  authorizer_policy: AuthorizerPolicy;
  settlement_method: "settle";
}

export interface VerifierReceipt {
  schema: typeof VERIFIER_RECEIPT_SCHEMA;
  accepted: boolean;
  reason: string;
  verifier_id: string;
  verifier_profile: string;
  proof_system: string;
  mode: string;
  packet_commitment: string;
  public_inputs_commitment: string;
  proof_ref: string;
  proof_digest: string;
  receipt_digest: string;
}

export interface SettlementAction {
  schema: typeof SETTLEMENT_ACTION_SCHEMA;
  chain_id: number;
  contract: string;
  method: "settle";
  args: {
    auth: {
      round_id_hash: string;
      token_contract: string;
      runtime_authorization_digest: string;
      runtime_mint_recipient_set_commitment: string;
      issued_unit_total: number;
      recipients: Array<{ account: string; amount: number }>;
    };
    signature: string | null;
  };
  signature_request: {
    authorizer_id: string;
    signing_domain: string;
    request_digest: string;
    settlement_digest_witness: string;
  };
  signature_status: "pending";
  action_digest: string;
}

export type WorkflowReceipt =
  | {
      schema: typeof WORKFLOW_RECEIPT_SCHEMA;
      accepted: true;
      reason: "accepted";
      workflow_id: string;
      workflow_engine: string;
      verifier_receipt_digest: string;
      authorizer_receipt_digest: string;
      settlement_action: SettlementAction;
      authorization_receipt: AuthorizerReceipt;
      receipt_digest: string;
    }
  | {
      schema: typeof WORKFLOW_RECEIPT_SCHEMA;
      accepted: false;
      reason: string;
      workflow_id: string;
      workflow_engine: string;
      verifier_receipt_digest: string | null;
      authorizer_receipt_digest: null;
      settlement_action: null;
      authorization_receipt: null;
      detail: Record<string, unknown>;
      receipt_digest: string;
    };

export interface WorkflowInput {
  packet: FundraisePacket;
  verifier_receipt: VerifierReceipt;
  policy?: Partial<WorkflowPolicy> & { authorizer_policy?: Partial<AuthorizerPolicy> };
  recipient_overrides?: Record<string, string>;
  verify_options?: VerifyOptions;
}

export declare class FundraiseWorkflowError extends Error {
  readonly reason: string;
  readonly detail: Record<string, unknown>;
  constructor(reason: string, message?: string, detail?: Record<string, unknown>);
}

export declare function createWorkflowPolicy(
  overrides?: Partial<WorkflowPolicy> & { authorizer_policy?: Partial<AuthorizerPolicy> },
): WorkflowPolicy;
export declare function packetCommitment(packet: FundraisePacket): string;
export declare function buildDemoVerifierReceipt(input: {
  packet: FundraisePacket;
  verifier_id?: string;
}): VerifierReceipt;
export declare function verifyVerifierReceipt(
  receipt: VerifierReceipt | unknown,
  input: { packet: FundraisePacket; policy?: Partial<WorkflowPolicy> },
): { accepted: true; reason: "accepted"; verifier_receipt: VerifierReceipt } | { accepted: false; reason: string };
export declare function runFundraiseWorkflow(input: WorkflowInput): WorkflowReceipt & { accepted: true };
export declare function authorizeFundraiseWorkflow(input: WorkflowInput): WorkflowReceipt;
export declare function buildSettlementAction(input: {
  policy: WorkflowPolicy;
  request: Extract<AuthorizerReceipt, { accepted: true }>["request"];
}): SettlementAction;
export declare function verifyWorkflowReceipt(
  receipt: WorkflowReceipt | unknown,
): { accepted: true; reason: "accepted"; settlement_action: SettlementAction } | { accepted: false; reason: string };
