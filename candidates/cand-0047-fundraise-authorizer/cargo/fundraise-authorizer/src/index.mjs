import {
  buildEvmMintAuthorization,
  canonical,
  digestHex,
  FundraiseVerificationError,
  verifyFundraisePacket,
} from "../../fundraise-runtime/src/index.mjs";

export const AUTHORIZER_RECEIPT_SCHEMA = "aac.fundraise-authorizer.receipt.v1";
export const SETTLEMENT_SIGNING_REQUEST_SCHEMA =
  "aac.fundraise-authorizer.settlement-signing-request.v1";
export const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";
export const DEFAULT_PROOF_VERIFIER_REF = "provekit-or-cre-verifier:pending";
export const DEFAULT_ADMISSIBILITY_REF = "cre-admissibility:demo";

export const DEFAULT_RECIPIENT_OVERRIDES = Object.freeze({
  "investor-a": "0xA11ce00000000000000000000000000000000039",
  "investor-b": "0xB0b0000000000000000000000000000000000039",
});

export class FundraiseAuthorizerError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseAuthorizerError";
    this.reason = reason;
    this.detail = detail;
  }
}

export function createAuthorizerPolicy(overrides = {}) {
  const roundId = overrides.round_id ?? "aac-seed-2026-001";
  const policy = {
    policy_id: "demo-cre-authorizer-policy",
    authorizer_id: "cre-demo-don",
    settlement_contract: "0x000000000000000000000000000000000000c0de",
    chain_id: 12_345,
    token_contract: "0xAac0000000000000000000000000000000000039",
    round_id: roundId,
    round_id_hash: digestHex("aac/fundraise/evm-round-id/1", roundId),
    verifier_profile: DEFAULT_VERIFIER_PROFILE,
    proof_verifier_ref: DEFAULT_PROOF_VERIFIER_REF,
    admissibility_ref: DEFAULT_ADMISSIBILITY_REF,
  };
  return validatePolicy({ ...policy, ...overrides });
}

export function buildSettlementSigningRequest({
  packet,
  policy: policyInput = {},
  recipient_overrides,
  verify_options = {},
} = {}) {
  if (!packet || typeof packet !== "object") {
    throw new FundraiseAuthorizerError("packet_missing");
  }

  const policy = createAuthorizerPolicy(policyInput);
  const result = verifyFundraisePacket(packet, verify_options);
  if (!result.accepted) {
    throw new FundraiseAuthorizerError("packet_rejected", `packet rejected: ${result.reason}`, {
      packet_reason: result.reason,
    });
  }

  const runtimeAuthorization = withEvmRecipients(result.authorization, recipient_overrides);
  const evm = buildEvmMintAuthorization(runtimeAuthorization, {
    tokenContract: policy.token_contract,
    roundIdHash: policy.round_id_hash,
  });
  assertPolicyBoundEvmAuthorization(policy, evm);

  const contractAuthorization = {
    round_id_hash: evm.round_id_hash,
    token_contract: evm.token_contract,
    runtime_authorization_digest: evm.runtime_authorization_digest,
    runtime_mint_recipient_set_commitment: evm.runtime_mint_recipient_set_commitment,
    issued_unit_total: evm.issued_unit_total,
    recipients: evm.recipients,
  };
  const requestCore = {
    schema: SETTLEMENT_SIGNING_REQUEST_SCHEMA,
    policy_id: policy.policy_id,
    authorizer_id: policy.authorizer_id,
    verifier_profile: policy.verifier_profile,
    proof_verifier_ref: policy.proof_verifier_ref,
    admissibility_ref: policy.admissibility_ref,
    chain_id: policy.chain_id,
    settlement_contract: policy.settlement_contract,
    signing_domain: "FundraiseMintSettlement.settlementDigest(auth)",
    runtime_round_id: evm.round_id,
    contract_authorization: contractAuthorization,
  };

  return {
    ...requestCore,
    settlement_digest_witness: hex32(
      digestHex("aac/fundraise-authorizer/settlement-digest-witness/1", requestCore),
    ),
    request_digest: hex32(digestHex("aac/fundraise-authorizer/signing-request/1", requestCore)),
  };
}

export function authorizeFundraisePacket(input = {}) {
  try {
    const policy = createAuthorizerPolicy(input.policy ?? {});
    const request = buildSettlementSigningRequest({
      packet: input.packet,
      policy,
      recipient_overrides: input.recipient_overrides,
      verify_options: input.verify_options,
    });
    const receipt = {
      schema: AUTHORIZER_RECEIPT_SCHEMA,
      accepted: true,
      reason: "accepted",
      policy,
      packet_commitment: digestHex("aac/fundraise-authorizer/packet/1", input.packet),
      request,
    };
    return { ...receipt, receipt_digest: receiptDigest(receipt) };
  } catch (err) {
    const reason = authorizerReason(err);
    const policy =
      err instanceof FundraiseAuthorizerError && err.reason === "policy_invalid"
        ? null
        : tryCreatePolicy(input.policy ?? {});
    const receipt = {
      schema: AUTHORIZER_RECEIPT_SCHEMA,
      accepted: false,
      reason,
      policy,
      packet_commitment: input.packet
        ? digestHex("aac/fundraise-authorizer/packet/1", input.packet)
        : null,
      request: null,
      detail: authorizerDetail(err),
    };
    return { ...receipt, receipt_digest: receiptDigest(receipt) };
  }
}

export function verifyAuthorizerReceipt(receipt) {
  try {
    if (!receipt || receipt.schema !== AUTHORIZER_RECEIPT_SCHEMA) {
      return { accepted: false, reason: "receipt_schema_mismatch" };
    }
    if (receipt.receipt_digest !== receiptDigest(receipt)) {
      return { accepted: false, reason: "receipt_digest_mismatch" };
    }
    if (receipt.accepted !== true) {
      return { accepted: false, reason: receipt.reason ?? "rejected" };
    }
    const request = receipt.request;
    if (!request || request.schema !== SETTLEMENT_SIGNING_REQUEST_SCHEMA) {
      return { accepted: false, reason: "request_schema_mismatch" };
    }
    if (request.settlement_digest_witness !== settlementDigestWitness(request)) {
      return { accepted: false, reason: "settlement_digest_witness_mismatch" };
    }
    if (request.request_digest !== signingRequestDigest(request)) {
      return { accepted: false, reason: "request_digest_mismatch" };
    }
    return { accepted: true, reason: "accepted", request };
  } catch (err) {
    return { accepted: false, reason: authorizerReason(err) };
  }
}

export function withEvmRecipients(authorization, recipientOverrides = {}) {
  if (!authorization || authorization.schema !== "aac.fundraise-runtime.authorized-mint.v1") {
    throw new FundraiseAuthorizerError("authorization_schema_mismatch");
  }
  const overrides = { ...DEFAULT_RECIPIENT_OVERRIDES, ...recipientOverrides };
  const ready = clone(authorization);
  ready.recipients = ready.recipients.map((recipient) => {
    const mapped = overrides[recipient.investor_id] ?? overrides[recipient.recipient] ?? recipient.recipient;
    if (!isEvmAddress(mapped)) {
      throw new FundraiseAuthorizerError("bad_mint_recipient", `bad recipient ${recipient.investor_id}`, {
        investor_id: recipient.investor_id,
      });
    }
    return { ...recipient, recipient: mapped };
  });
  return ready;
}

export function settlementDigestWitness(request) {
  return hex32(
    digestHex("aac/fundraise-authorizer/settlement-digest-witness/1", requestDigestPayload(request)),
  );
}

export function signingRequestDigest(request) {
  return hex32(
    digestHex("aac/fundraise-authorizer/signing-request/1", requestDigestPayload(request)),
  );
}

function requestDigestPayload(request) {
  const {
    settlement_digest_witness: _settlementDigestWitness,
    request_digest: _requestDigest,
    ...payload
  } = request;
  return payload;
}

function assertPolicyBoundEvmAuthorization(policy, evm) {
  if (evm.token_contract !== policy.token_contract) {
    throw new FundraiseAuthorizerError("token_contract_mismatch");
  }
  if (evm.round_id_hash !== hex32(policy.round_id_hash)) {
    throw new FundraiseAuthorizerError("round_id_hash_mismatch");
  }
  if (!Number.isSafeInteger(evm.issued_unit_total) || evm.issued_unit_total <= 0) {
    throw new FundraiseAuthorizerError("issued_unit_total_invalid");
  }
  const total = evm.recipients.reduce((sum, recipient) => sum + recipient.amount, 0);
  if (total !== evm.issued_unit_total) {
    throw new FundraiseAuthorizerError("issued_total_mismatch");
  }
}

function validatePolicy(policy) {
  if (!policy.policy_id) throw policyError("policy_id_missing");
  if (!policy.authorizer_id) throw policyError("authorizer_id_missing");
  if (!isEvmAddress(policy.settlement_contract)) throw policyError("bad_settlement_contract");
  if (!Number.isSafeInteger(policy.chain_id) || policy.chain_id <= 0) throw policyError("bad_chain_id");
  if (!isEvmAddress(policy.token_contract)) throw policyError("bad_token_contract");
  policy.round_id_hash = hex32(policy.round_id_hash).slice(2);
  if (!policy.verifier_profile) throw policyError("verifier_profile_missing");
  if (!policy.proof_verifier_ref) throw policyError("proof_verifier_ref_missing");
  if (!policy.admissibility_ref) throw policyError("admissibility_ref_missing");
  return policy;
}

function policyError(reason) {
  return new FundraiseAuthorizerError("policy_invalid", reason, { policy_reason: reason });
}

function tryCreatePolicy(overrides) {
  try {
    return createAuthorizerPolicy(overrides);
  } catch {
    return null;
  }
}

function receiptDigest(receipt) {
  const { receipt_digest: _receiptDigest, ...payload } = receipt;
  return hex32(digestHex("aac/fundraise-authorizer/receipt/1", payload));
}

function authorizerReason(err) {
  if (err instanceof FundraiseAuthorizerError) return err.reason;
  if (err instanceof FundraiseVerificationError) return err.reason;
  return "authorizer_error";
}

function authorizerDetail(err) {
  if (err instanceof FundraiseAuthorizerError) return err.detail;
  if (err instanceof FundraiseVerificationError) return { fundraise_reason: err.reason };
  return {};
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function isEvmAddress(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{40}$/.test(value);
}

function hex32(value) {
  if (typeof value !== "string") throw new FundraiseAuthorizerError("bad_bytes32");
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) throw new FundraiseAuthorizerError("bad_bytes32");
  return `0x${raw.toLowerCase()}`;
}

export { canonical, digestHex };
