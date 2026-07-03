import { createHash } from "node:crypto";
import {
  packetCommitment,
  VERIFIER_RECEIPT_SCHEMA,
  verifyVerifierReceipt,
} from "../../fundraise-workflow/src/index.mjs";
import { digestHex } from "../../fundraise-authorizer/src/index.mjs";

export const PROVEKIT_ADAPTER_SCHEMA = "aac.fundraise-provekit-adapter.input.v1";
export const PROVEKIT_PROOF_SYSTEMS = Object.freeze(["provekit-whir", "provekit-groth16"]);
export const PROVEKIT_MODES = Object.freeze(["native-cli", "browser-wasm", "service", "cre-workflow"]);
export const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";

export class FundraiseProveKitAdapterError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseProveKitAdapterError";
    this.reason = reason;
    this.detail = detail;
  }
}

export function buildProveKitVerifierReceipt({
  packet,
  provekit,
  verifier_id = "provekit-verifier",
  verifier_profile = DEFAULT_VERIFIER_PROFILE,
} = {}) {
  if (!packet || typeof packet !== "object") {
    throw new FundraiseProveKitAdapterError("packet_missing");
  }
  const normalized = normalizeProveKitResult(provekit);
  const core = {
    schema: VERIFIER_RECEIPT_SCHEMA,
    accepted: true,
    reason: "accepted",
    verifier_id,
    verifier_profile,
    proof_system: normalized.proof_system,
    mode: normalized.mode,
    packet_commitment: packetCommitment(packet),
    public_inputs_commitment: digestHex(
      "aac/fundraise-provekit/public-inputs/1",
      normalized.public_inputs,
    ),
    proof_ref: normalized.proof_ref,
    proof_digest: normalized.proof_digest,
    verifier_key_digest: normalized.verifier_key_digest,
    timings_ms: normalized.timings_ms,
    adapter_schema: PROVEKIT_ADAPTER_SCHEMA,
  };
  return { ...core, receipt_digest: verifierReceiptDigest(core) };
}

export function verifyProveKitVerifierReceipt(receipt, { packet, policy = {} } = {}) {
  const basic = verifyVerifierReceipt(receipt, { packet, policy });
  if (!basic.accepted) return basic;
  if (!receipt || !PROVEKIT_PROOF_SYSTEMS.includes(receipt.proof_system)) {
    return { accepted: false, reason: "provekit_proof_system_mismatch" };
  }
  if (!PROVEKIT_MODES.includes(receipt.mode)) {
    return { accepted: false, reason: "provekit_mode_mismatch" };
  }
  if (receipt.adapter_schema !== PROVEKIT_ADAPTER_SCHEMA) {
    return { accepted: false, reason: "provekit_adapter_schema_mismatch" };
  }
  if (!isHex32(receipt.verifier_key_digest)) {
    return { accepted: false, reason: "provekit_verifier_key_digest_mismatch" };
  }
  return { accepted: true, reason: "accepted", verifier_receipt: receipt };
}

export function normalizeProveKitResult(provekit) {
  if (!provekit || typeof provekit !== "object") {
    throw new FundraiseProveKitAdapterError("provekit_result_missing");
  }
  if (provekit.accepted !== true) {
    throw new FundraiseProveKitAdapterError("provekit_rejected", provekit.reason ?? "provekit_rejected", {
      provekit_reason: provekit.reason ?? "rejected",
    });
  }
  if (!PROVEKIT_PROOF_SYSTEMS.includes(provekit.proof_system)) {
    throw new FundraiseProveKitAdapterError("bad_proof_system");
  }
  if (!PROVEKIT_MODES.includes(provekit.mode)) {
    throw new FundraiseProveKitAdapterError("bad_provekit_mode");
  }
  if (provekit.public_inputs === undefined || provekit.public_inputs === null) {
    throw new FundraiseProveKitAdapterError("public_inputs_missing");
  }
  const proofDigest = provekit.proof_digest ?? digestBytesOrJson("aac/fundraise-provekit/proof/1", provekit.proof);
  if (!isHex32(proofDigest)) {
    throw new FundraiseProveKitAdapterError("bad_proof_digest");
  }
  const verifierKeyDigest = provekit.verifier_key_digest ?? provekit.vk_digest;
  if (!isHex32(verifierKeyDigest)) {
    throw new FundraiseProveKitAdapterError("bad_verifier_key_digest");
  }
  const timings = provekit.timings_ms ?? {};
  return {
    proof_system: provekit.proof_system,
    mode: provekit.mode,
    public_inputs: provekit.public_inputs,
    proof_digest: hex32(proofDigest),
    proof_ref: provekit.proof_ref ?? `${provekit.proof_system}:${provekit.mode}:${hex32(proofDigest).slice(2, 14)}`,
    verifier_key_digest: hex32(verifierKeyDigest),
    timings_ms: normalizeTimings(timings),
  };
}

function normalizeTimings(timings) {
  const out = {};
  for (const [key, value] of Object.entries(timings)) {
    if (!Number.isFinite(value) || value < 0) {
      throw new FundraiseProveKitAdapterError("bad_timing");
    }
    out[key] = value;
  }
  return out;
}

function verifierReceiptDigest(receipt) {
  const { receipt_digest: _receiptDigest, ...payload } = receipt;
  return hex32(digestHex("aac/fundraise-workflow/verifier-receipt/1", payload));
}

function digestBytesOrJson(label, value) {
  if (value === undefined || value === null) {
    throw new FundraiseProveKitAdapterError("proof_missing");
  }
  const hash = createHash("sha256");
  hash.update(label);
  if (value instanceof Uint8Array) {
    hash.update(value);
  } else if (typeof value === "string") {
    hash.update(value);
  } else {
    hash.update(JSON.stringify(value));
  }
  return `0x${hash.digest("hex")}`;
}

function isHex32(value) {
  if (typeof value !== "string") return false;
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  return /^[0-9a-fA-F]{64}$/.test(raw);
}

function hex32(value) {
  if (!isHex32(value)) throw new FundraiseProveKitAdapterError("bad_bytes32");
  return `0x${(value.startsWith("0x") ? value.slice(2) : value).toLowerCase()}`;
}
