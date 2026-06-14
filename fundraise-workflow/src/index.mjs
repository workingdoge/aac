import {
  authorizeFundraisePacket,
  createAuthorizerPolicy,
  digestHex,
  verifyAuthorizerReceipt,
} from "../../fundraise-authorizer/src/index.mjs";

export const WORKFLOW_RECEIPT_SCHEMA = "aac.fundraise-workflow.receipt.v1";
export const VERIFIER_RECEIPT_SCHEMA = "aac.fundraise-workflow.verifier-receipt.v1";
export const SETTLEMENT_ACTION_SCHEMA = "aac.fundraise-workflow.settlement-action.v1";
export const DEFAULT_WORKFLOW_ID = "aac-fundraise-authorizer-workflow";
export const DEFAULT_WORKFLOW_ENGINE = "cre-sdk-wrapper:pending";
export const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";

export class FundraiseWorkflowError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseWorkflowError";
    this.reason = reason;
    this.detail = detail;
  }
}

export function createWorkflowPolicy(overrides = {}) {
  const authorizerPolicy = createAuthorizerPolicy(overrides.authorizer_policy ?? {});
  const policy = {
    workflow_id: DEFAULT_WORKFLOW_ID,
    workflow_engine: DEFAULT_WORKFLOW_ENGINE,
    verifier_profile: DEFAULT_VERIFIER_PROFILE,
    accepted_proof_systems: ["runtime-reference", "provekit-whir", "provekit-groth16"],
    require_live_proof: false,
    authorizer_policy: authorizerPolicy,
    settlement_method: "settle",
    ...overrides,
    authorizer_policy: authorizerPolicy,
  };
  return validateWorkflowPolicy(policy);
}

export function packetCommitment(packet) {
  if (!packet || typeof packet !== "object") {
    throw new FundraiseWorkflowError("packet_missing");
  }
  return digestHex("aac/fundraise-authorizer/packet/1", packet);
}

export function buildDemoVerifierReceipt({ packet, verifier_id = "runtime-reference-verifier" } = {}) {
  const core = {
    schema: VERIFIER_RECEIPT_SCHEMA,
    accepted: true,
    reason: "accepted",
    verifier_id,
    verifier_profile: DEFAULT_VERIFIER_PROFILE,
    proof_system: "runtime-reference",
    mode: "simulation",
    packet_commitment: packetCommitment(packet),
    public_inputs_commitment: digestHex(
      "aac/fundraise-workflow/public-inputs/1",
      packet.public_inputs ?? null,
    ),
    proof_ref: "runtime-reference:fundraise-runtime",
    proof_digest: digestHex("aac/fundraise-workflow/runtime-reference-proof/1", packet.public_inputs ?? null),
  };
  return { ...core, receipt_digest: verifierReceiptDigest(core) };
}

export function verifyVerifierReceipt(receipt, { packet, policy: policyInput = {} } = {}) {
  try {
    const policy = createWorkflowPolicy(policyInput);
    if (!receipt || receipt.schema !== VERIFIER_RECEIPT_SCHEMA) {
      return { accepted: false, reason: "verifier_receipt_schema_mismatch" };
    }
    if (receipt.receipt_digest !== verifierReceiptDigest(receipt)) {
      return { accepted: false, reason: "verifier_receipt_digest_mismatch" };
    }
    if (receipt.accepted !== true) {
      return { accepted: false, reason: receipt.reason ?? "verifier_rejected" };
    }
    if (receipt.packet_commitment !== packetCommitment(packet)) {
      return { accepted: false, reason: "verifier_packet_mismatch" };
    }
    if (receipt.verifier_profile !== policy.verifier_profile) {
      return { accepted: false, reason: "verifier_profile_mismatch" };
    }
    if (!policy.accepted_proof_systems.includes(receipt.proof_system)) {
      return { accepted: false, reason: "verifier_proof_system_not_allowed" };
    }
    if (policy.require_live_proof && receipt.proof_system === "runtime-reference") {
      return { accepted: false, reason: "live_proof_required" };
    }
    if (!receipt.public_inputs_commitment || !receipt.proof_digest) {
      return { accepted: false, reason: "verifier_receipt_incomplete" };
    }
    return { accepted: true, reason: "accepted", verifier_receipt: receipt };
  } catch (err) {
    return { accepted: false, reason: workflowReason(err) };
  }
}

export function runFundraiseWorkflow(input = {}) {
  const policy = createWorkflowPolicy(input.policy ?? {});
  const verifier = verifyVerifierReceipt(input.verifier_receipt, {
    packet: input.packet,
    policy,
  });
  if (!verifier.accepted) {
    throw new FundraiseWorkflowError(verifier.reason);
  }

  const authorizationReceipt = authorizeFundraisePacket({
    packet: input.packet,
    policy: policy.authorizer_policy,
    recipient_overrides: input.recipient_overrides,
    verify_options: input.verify_options,
  });
  if (!authorizationReceipt.accepted) {
    throw new FundraiseWorkflowError("authorizer_rejected", authorizationReceipt.reason, {
      authorizer_reason: authorizationReceipt.reason,
    });
  }
  const authCheck = verifyAuthorizerReceipt(authorizationReceipt);
  if (!authCheck.accepted) {
    throw new FundraiseWorkflowError("authorizer_receipt_invalid", authCheck.reason, {
      authorizer_reason: authCheck.reason,
    });
  }

  const settlementAction = buildSettlementAction({
    policy,
    request: authorizationReceipt.request,
  });
  const core = {
    schema: WORKFLOW_RECEIPT_SCHEMA,
    accepted: true,
    reason: "accepted",
    workflow_id: policy.workflow_id,
    workflow_engine: policy.workflow_engine,
    verifier_receipt_digest: input.verifier_receipt.receipt_digest,
    authorizer_receipt_digest: authorizationReceipt.receipt_digest,
    settlement_action: settlementAction,
  };
  return {
    ...core,
    authorization_receipt: authorizationReceipt,
    receipt_digest: workflowReceiptDigest({ ...core, authorization_receipt: authorizationReceipt }),
  };
}

export function authorizeFundraiseWorkflow(input = {}) {
  try {
    return runFundraiseWorkflow(input);
  } catch (err) {
    const core = {
      schema: WORKFLOW_RECEIPT_SCHEMA,
      accepted: false,
      reason: workflowReason(err),
      workflow_id: input.policy?.workflow_id ?? DEFAULT_WORKFLOW_ID,
      workflow_engine: input.policy?.workflow_engine ?? DEFAULT_WORKFLOW_ENGINE,
      verifier_receipt_digest: input.verifier_receipt?.receipt_digest ?? null,
      authorizer_receipt_digest: null,
      settlement_action: null,
      authorization_receipt: null,
      detail: workflowDetail(err),
    };
    return { ...core, receipt_digest: workflowReceiptDigest(core) };
  }
}

export function buildSettlementAction({ policy, request } = {}) {
  if (!request?.contract_authorization) {
    throw new FundraiseWorkflowError("signing_request_missing");
  }
  const core = {
    schema: SETTLEMENT_ACTION_SCHEMA,
    chain_id: request.chain_id,
    contract: request.settlement_contract,
    method: policy.settlement_method,
    args: {
      auth: request.contract_authorization,
      signature: null,
    },
    signature_request: {
      authorizer_id: request.authorizer_id,
      signing_domain: request.signing_domain,
      request_digest: request.request_digest,
      settlement_digest_witness: request.settlement_digest_witness,
    },
    signature_status: "pending",
  };
  return { ...core, action_digest: settlementActionDigest(core) };
}

export function verifyWorkflowReceipt(receipt) {
  try {
    if (!receipt || receipt.schema !== WORKFLOW_RECEIPT_SCHEMA) {
      return { accepted: false, reason: "workflow_receipt_schema_mismatch" };
    }
    if (receipt.receipt_digest !== workflowReceiptDigest(receipt)) {
      return { accepted: false, reason: "workflow_receipt_digest_mismatch" };
    }
    if (receipt.accepted !== true) {
      return { accepted: false, reason: receipt.reason ?? "workflow_rejected" };
    }
    const action = receipt.settlement_action;
    if (!action || action.schema !== SETTLEMENT_ACTION_SCHEMA) {
      return { accepted: false, reason: "settlement_action_schema_mismatch" };
    }
    if (action.action_digest !== settlementActionDigest(action)) {
      return { accepted: false, reason: "settlement_action_digest_mismatch" };
    }
    const authCheck = verifyAuthorizerReceipt(receipt.authorization_receipt);
    if (!authCheck.accepted) {
      return { accepted: false, reason: "authorizer_receipt_invalid" };
    }
    return { accepted: true, reason: "accepted", settlement_action: action };
  } catch (err) {
    return { accepted: false, reason: workflowReason(err) };
  }
}

function validateWorkflowPolicy(policy) {
  if (!policy.workflow_id) throw policyError("workflow_id_missing");
  if (!policy.workflow_engine) throw policyError("workflow_engine_missing");
  if (!policy.verifier_profile) throw policyError("verifier_profile_missing");
  if (!Array.isArray(policy.accepted_proof_systems) || policy.accepted_proof_systems.length === 0) {
    throw policyError("accepted_proof_systems_missing");
  }
  if (typeof policy.require_live_proof !== "boolean") throw policyError("bad_require_live_proof");
  if (policy.settlement_method !== "settle") throw policyError("bad_settlement_method");
  return policy;
}

function policyError(reason) {
  return new FundraiseWorkflowError("workflow_policy_invalid", reason, { policy_reason: reason });
}

function verifierReceiptDigest(receipt) {
  const { receipt_digest: _receiptDigest, ...payload } = receipt;
  return hex32(digestHex("aac/fundraise-workflow/verifier-receipt/1", payload));
}

function workflowReceiptDigest(receipt) {
  const { receipt_digest: _receiptDigest, ...payload } = receipt;
  return hex32(digestHex("aac/fundraise-workflow/receipt/1", payload));
}

function settlementActionDigest(action) {
  const { action_digest: _actionDigest, ...payload } = action;
  return hex32(digestHex("aac/fundraise-workflow/settlement-action/1", payload));
}

function workflowReason(err) {
  if (err instanceof FundraiseWorkflowError) return err.reason;
  return "workflow_error";
}

function workflowDetail(err) {
  if (err instanceof FundraiseWorkflowError) return err.detail;
  return {};
}

function hex32(value) {
  if (typeof value !== "string") throw new FundraiseWorkflowError("bad_bytes32");
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) throw new FundraiseWorkflowError("bad_bytes32");
  return `0x${raw.toLowerCase()}`;
}
