import { createHash } from "node:crypto";
import {
  buildBilateralPacket,
  verifyBilateralCertificate,
} from "../../bcc-runtime/src/index.mjs";
import {
  verifyVnetLink as verifyVnetLinkReference,
} from "../../vnet-runtime/src/index.mjs";

export const SCHEMA = "aac.fundraise-demo.conformance.v1";
export const SETTLEMENT_ASSET = "USDC:arc-testnet:atomic";
export const ISSUED_UNIT = "SAFE:issuer:series-a:unit";

export class FundraiseVerificationError extends Error {
  constructor(reason, message = reason) {
    super(message);
    this.name = "FundraiseVerificationError";
    this.reason = reason;
  }
}

export function canonical(value) {
  return JSON.stringify(sortCanonical(value));
}

export function digestHex(label, ...parts) {
  return createHash("sha256")
    .update(canonical([label, ...parts]))
    .digest("hex");
}

function sortCanonical(value) {
  if (Array.isArray(value)) return value.map(sortCanonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, v]) => [k, sortCanonical(v)]),
    );
  }
  return value;
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

export function createRoundPolicy(overrides = {}) {
  const policy = {
    round_id: "aac-seed-2026-001",
    issuer_name: "issuer-a.private-row",
    settlement_asset_type_id: SETTLEMENT_ASSET,
    issued_unit_type_id: ISSUED_UNIT,
    price_numerator: 10,
    price_denominator: 1,
    max_settlement_amount: 2_000,
    max_issued_units: 200,
    token_contract: "0xAac000000000000000000000000000000000039",
    settlement_chain: "arc-testnet",
    vault_or_contract: "0xVa01700000000000000000000000000000000039",
    transfer_policy_hash: digestHex("aac/demo/transfer-policy", "restricted-safe"),
    admissibility_policy_hash: digestHex("aac/demo/admissibility-policy", "allowlist"),
    settlement_adapter_hash: digestHex("aac/demo/settlement-adapter", "arc-usdc-report"),
  };
  return { ...policy, ...overrides };
}

export function createSubscription(input) {
  const required = [
    "subscription_id",
    "investor_id",
    "mint_recipient",
    "settlement_ref",
    "settlement_amount",
    "issued_units",
    "admissibility_ref",
    "subscription_nullifier",
  ];
  for (const key of required) {
    if (input[key] === undefined || input[key] === null || input[key] === "") {
      throw new FundraiseVerificationError("subscription_field_missing", `missing ${key}`);
    }
  }
  if (!Number.isSafeInteger(input.settlement_amount) || input.settlement_amount < 0) {
    throw new FundraiseVerificationError("bad_settlement_amount");
  }
  if (!Number.isSafeInteger(input.issued_units) || input.issued_units < 0) {
    throw new FundraiseVerificationError("bad_issued_units");
  }
  return { ...input };
}

export function buildSettlementReport(policy, subscriptions) {
  return {
    schema: "aac.fundraise-demo.settlement-report.v1",
    adapter_hash: policy.settlement_adapter_hash,
    accepted: subscriptions.map((sub) => ({
      settlement_ref: sub.settlement_ref,
      investor_id: sub.investor_id,
      asset_type_id: policy.settlement_asset_type_id,
      amount: sub.settlement_amount,
    })),
  };
}

export function buildBridgeSettlement(policy, subscriptions) {
  return {
    schema: "aac.fundraise-demo.bridge-settlement.v1",
    settlement_chain: policy.settlement_chain,
    vault_or_contract: policy.vault_or_contract,
    asset_type_id: policy.settlement_asset_type_id,
    accepted: subscriptions.map((sub) => ({
      subscription_id: sub.subscription_id,
      investor_id: sub.investor_id,
      settlement_ref: sub.settlement_ref,
      deposit_ref: sub.settlement_ref,
      amount: sub.settlement_amount,
    })),
  };
}

export function buildAdmissibilityReport(policy, subscriptions) {
  return {
    schema: "aac.fundraise-demo.admissibility-report.v1",
    policy_hash: policy.admissibility_policy_hash,
    accepted: subscriptions.map((sub) => ({
      admissibility_ref: sub.admissibility_ref,
      investor_id: sub.investor_id,
      accepted: true,
    })),
  };
}

export function buildMintAuthorization(policy, subscriptions) {
  const recipients = subscriptions.map((sub) => ({
    investor_id: sub.investor_id,
    recipient: sub.mint_recipient,
    issued_units: sub.issued_units,
  }));
  return {
    schema: "aac.fundraise-demo.mint-authorization.v1",
    round_id: policy.round_id,
    token_contract: policy.token_contract,
    issued_unit_total: recipients.reduce((sum, r) => sum + r.issued_units, 0),
    mint_recipient_set_commitment: digestHex("aac/fundraise/mint-recipients/1", recipients),
    recipients,
  };
}

export function vnetPublic(vnetLink) {
  const vnet = vnetLink.vnet;
  return {
    profile_id: vnet.profile_id,
    basis_commitment: vnet.basis_commitment,
    aggregate_opening: vnet.aggregate_opening,
    atom_count: vnet.atoms.length,
    transition_refs: vnet.atoms.map((atom) => ({
      transition_ref: atom.transition_ref,
      journal_commitment: atom.journal_commitment,
    })),
  };
}

export function bccPublic(agreement) {
  const cert = agreement.certificate;
  return {
    subscription_id: agreement.subscription_id,
    transcript_hash: cert.transcript_hash,
    finality_tag: cert.finality.finality_tag,
    nullifier: cert.finality.nullifier,
    parties: cert.records.map((record) => record.party_id),
    record_commitments: cert.records.map((record) => record.record_commitment.value),
  };
}

export function buildBccAgreements(policy, subscriptions, vnetLink) {
  const atoms = vnetLink.vnet.atoms;
  return subscriptions.map((sub, index) => {
    const investorAtom = atoms[index * 2];
    const issuerAtom = atoms[index * 2 + 1];
    const event = {
      event_id: `fundraise:${policy.round_id}:${sub.subscription_id}`,
      description: `Investor ${sub.investor_id} subscribes to ${sub.issued_units} issued units for ${sub.settlement_amount} settlement units.`,
      basis_type_ids: [policy.settlement_asset_type_id, policy.issued_unit_type_id],
      state_refs: {
        investor_row: investorAtom.transition_ref,
        issuer_row: issuerAtom.transition_ref,
      },
      fundraise_context: {
        round_id: policy.round_id,
        issuer_name: policy.issuer_name,
        investor_id: sub.investor_id,
        subscription_id: sub.subscription_id,
        settlement_ref: sub.settlement_ref,
        settlement_amount: sub.settlement_amount,
        issued_units: sub.issued_units,
        token_contract: policy.token_contract,
      },
      bridge_context: {
        asset: policy.settlement_asset_type_id,
        settlement_chain: policy.settlement_chain,
        vault_or_contract: policy.vault_or_contract,
        deposit_ref: sub.settlement_ref,
      },
    };
    const packet = buildBilateralPacket({
      event,
      records: [
        {
          party_id: sub.investor_id,
          role: "investor",
          transition_ref: investorAtom.transition_ref,
          journal_commitment: investorAtom.journal_commitment,
          basis_type_ids: event.basis_type_ids,
          debit: [0, sub.issued_units],
          credit: [sub.settlement_amount, 0],
        },
        {
          party_id: policy.issuer_name,
          role: "issuer",
          transition_ref: issuerAtom.transition_ref,
          journal_commitment: issuerAtom.journal_commitment,
          basis_type_ids: event.basis_type_ids,
          debit: [sub.settlement_amount, 0],
          credit: [0, sub.issued_units],
        },
      ],
      finality_context: {
        log_ref: `fundraise:${policy.round_id}`,
        nullifier: sub.subscription_nullifier,
      },
    });
    return {
      schema: "aac.fundraise-demo.bcc-agreement.v1",
      subscription_id: sub.subscription_id,
      certificate: packet.certificate,
    };
  });
}

export function buildPublicInputs(policy, subscriptions, vnetLink, mintAuthorization, bccAgreements, bridgeSettlement) {
  const settlementReport = buildSettlementReport(policy, subscriptions);
  const admissibilityReport = buildAdmissibilityReport(policy, subscriptions);
  const transitions = vnetPublic(vnetLink).transition_refs;
  const settlementTotal = subscriptions.reduce((sum, sub) => sum + sub.settlement_amount, 0);
  const issuedTotal = subscriptions.reduce((sum, sub) => sum + sub.issued_units, 0);
  return {
    round_id: policy.round_id,
    issuer_name: policy.issuer_name,
    prev_balance_sheet_root: digestHex("aac/demo/root", "balance-sheet", "prev"),
    next_balance_sheet_root: digestHex("aac/demo/root", "balance-sheet", "next"),
    prev_cap_table_root: digestHex("aac/demo/root", "cap-table", "prev"),
    next_cap_table_root: digestHex("aac/demo/root", "cap-table", "next"),
    subscription_set_commitment: digestHex("aac/fundraise/subscriptions/1", subscriptions),
    transition_set_commitment: digestHex("aac/fundraise/transitions/1", transitions),
    vnet_public_commitment: digestHex("aac/fundraise/vnet-public/1", vnetPublic(vnetLink)),
    bcc_set_commitment: digestHex("aac/fundraise/bcc-agreements/1", bccAgreements.map(bccPublic)),
    bridge_settlement_commitment: digestHex("aac/fundraise/bridge-settlement/1", bridgeSettlement),
    mint_recipient_set_commitment: mintAuthorization.mint_recipient_set_commitment,
    settlement_amount_total: settlementTotal,
    issued_unit_total: issuedTotal,
    token_contract: mintAuthorization.token_contract,
    context_commitment: digestHex("aac/fundraise/context/1", policy, settlementReport, admissibilityReport, bridgeSettlement),
  };
}

export function buildFundraisePacket({
  policy,
  subscriptions,
  vnetLink,
  bccAgreements,
  bridgeSettlement,
  settlementReport,
  admissibilityReport,
  mintAuthorization,
}) {
  const normalizedPolicy = policy ?? createRoundPolicy();
  const normalizedSubscriptions = subscriptions.map(createSubscription);
  const mint = mintAuthorization ?? buildMintAuthorization(normalizedPolicy, normalizedSubscriptions);
  const bridge = bridgeSettlement ?? buildBridgeSettlement(normalizedPolicy, normalizedSubscriptions);
  const bcc = bccAgreements ?? buildBccAgreements(normalizedPolicy, normalizedSubscriptions, vnetLink);
  return {
    round_policy: normalizedPolicy,
    subscriptions: normalizedSubscriptions,
    bcc_agreements: bcc,
    bridge_settlement: bridge,
    settlement_report: settlementReport ?? buildSettlementReport(normalizedPolicy, normalizedSubscriptions),
    admissibility_report: admissibilityReport ?? buildAdmissibilityReport(normalizedPolicy, normalizedSubscriptions),
    vnet_link: clone(vnetLink),
    mint_authorization: mint,
    public_inputs: buildPublicInputs(normalizedPolicy, normalizedSubscriptions, vnetLink, mint, bcc, bridge),
  };
}

export function verifyFundraisePacket(packet, opts = {}) {
  try {
    checkPacket(packet, opts);
    return { accepted: true, reason: "accepted", authorization: authorizeMint(packet) };
  } catch (err) {
    if (err instanceof FundraiseVerificationError) {
      return { accepted: false, reason: err.reason };
    }
    throw err;
  }
}

export function authorizeMint(packet) {
  const pub = packet.public_inputs;
  const mint = packet.mint_authorization;
  return {
    schema: "aac.fundraise-runtime.authorized-mint.v1",
    round_id: pub.round_id,
    token_contract: pub.token_contract,
    issued_unit_total: pub.issued_unit_total,
    mint_recipient_set_commitment: pub.mint_recipient_set_commitment,
    authorization_digest: digestHex("aac/fundraise/authorized-mint/1", {
      round_id: pub.round_id,
      token_contract: pub.token_contract,
      issued_unit_total: pub.issued_unit_total,
      mint_recipient_set_commitment: pub.mint_recipient_set_commitment,
      vnet_public_commitment: pub.vnet_public_commitment,
      bcc_set_commitment: pub.bcc_set_commitment,
      bridge_settlement_commitment: pub.bridge_settlement_commitment,
      context_commitment: pub.context_commitment,
    }),
    recipients: clone(mint.recipients),
  };
}

export function buildEvmMintAuthorization(authorization, opts = {}) {
  if (authorization?.schema !== "aac.fundraise-runtime.authorized-mint.v1") {
    throw new FundraiseVerificationError("authorization_schema_mismatch");
  }
  const token = opts.tokenContract ?? opts.token_contract ?? authorization.token_contract;
  if (!isEvmAddress(token)) throw new FundraiseVerificationError("bad_token_contract");
  const roundIdHash = opts.roundIdHash ?? opts.round_id_hash ?? digestHex("aac/fundraise/evm-round-id/1", authorization.round_id);
  const recipients = authorization.recipients.map((recipient) => {
    if (!isEvmAddress(recipient.recipient)) throw new FundraiseVerificationError("bad_mint_recipient");
    return {
      account: recipient.recipient,
      amount: recipient.issued_units,
    };
  });
  return {
    schema: "aac.fundraise-runtime.evm-mint-authorization.v1",
    round_id: authorization.round_id,
    round_id_hash: hex32(roundIdHash),
    token_contract: token,
    runtime_authorization_digest: hex32(authorization.authorization_digest),
    runtime_mint_recipient_set_commitment: hex32(authorization.mint_recipient_set_commitment),
    issued_unit_total: authorization.issued_unit_total,
    recipients,
  };
}

function checkPacket(packet, opts) {
  const policy = packet.round_policy;
  const subscriptions = packet.subscriptions;
  const pub = packet.public_inputs;
  const mint = packet.mint_authorization;
  const bccAgreements = packet.bcc_agreements;
  const bridge = packet.bridge_settlement;

  if (pub.round_id !== policy.round_id) fail("round_id_mismatch");
  if (pub.token_contract !== mint.token_contract) fail("public_token_mismatch");
  if (mint.round_id !== policy.round_id) fail("mint_round_mismatch");
  if (mint.token_contract !== policy.token_contract) fail("token_contract_mismatch");
  if (!Array.isArray(bccAgreements) || bccAgreements.length !== subscriptions.length) fail("bcc_missing");
  if (!bridge || bridge.schema !== "aac.fundraise-demo.bridge-settlement.v1") fail("bridge_missing");
  if (bridge.settlement_chain !== policy.settlement_chain) fail("bridge_chain_mismatch");
  if (bridge.vault_or_contract !== policy.vault_or_contract) fail("bridge_contract_mismatch");
  if (bridge.asset_type_id !== policy.settlement_asset_type_id) fail("bridge_asset_mismatch");

  const settlement = new Map(packet.settlement_report.accepted.map((item) => [item.settlement_ref, item]));
  const admissibility = new Map(packet.admissibility_report.accepted.map((item) => [item.admissibility_ref, item]));
  const bccBySubscription = new Map(bccAgreements.map((item) => [item.subscription_id, item]));
  const bridgeBySubscription = new Map(bridge.accepted.map((item) => [item.subscription_id, item]));
  const nullifiers = new Set();
  const bccFinalityTags = new Set(opts.seenBccFinalityTags ?? opts.seen_bcc_finality_tags ?? []);
  let settlementTotal = 0;
  let issuedTotal = 0;

  for (const sub of subscriptions) {
    if (sub.settlement_amount * policy.price_denominator !== sub.issued_units * policy.price_numerator) {
      fail("price_mismatch");
    }
    if (sub.subscription_nullifier === "0" || sub.subscription_nullifier === "0x0" || sub.subscription_nullifier === "") {
      fail("zero_nullifier");
    }
    if (nullifiers.has(sub.subscription_nullifier)) fail("duplicate_nullifier");
    nullifiers.add(sub.subscription_nullifier);

    const reported = settlement.get(sub.settlement_ref);
    if (!reported) fail("settlement_report_missing");
    if (reported.investor_id !== sub.investor_id) fail("settlement_report_mismatch");
    if (reported.asset_type_id !== policy.settlement_asset_type_id) fail("settlement_asset_mismatch");
    if (reported.amount !== sub.settlement_amount) fail("settlement_amount_mismatch");

    const admitted = admissibility.get(sub.admissibility_ref);
    if (!admitted || admitted.accepted !== true) fail("admissibility_missing");
    if (admitted.investor_id !== sub.investor_id) fail("admissibility_mismatch");

    const bridgeItem = bridgeBySubscription.get(sub.subscription_id);
    if (!bridgeItem) fail("bridge_settlement_missing");
    if (bridgeItem.investor_id !== sub.investor_id) fail("bridge_settlement_mismatch");
    if (bridgeItem.settlement_ref !== sub.settlement_ref) fail("bridge_settlement_mismatch");
    if (bridgeItem.deposit_ref !== sub.settlement_ref) fail("bridge_deposit_mismatch");
    if (bridgeItem.amount !== sub.settlement_amount) fail("bridge_amount_mismatch");

    const bcc = bccBySubscription.get(sub.subscription_id);
    if (!bcc) fail("bcc_missing");
    const cert = bcc.certificate;
    if (bccFinalityTags.has(cert.finality.finality_tag)) fail("bcc_finality_replay");
    const bccResult = verifyBilateralCertificate(cert, {
      seenFinalityTags: bccFinalityTags,
      verifySignature: opts.verifyBccSignature ?? opts.verify_bcc_signature,
      verifyCancellation: opts.verifyBccCancellation ?? opts.verify_bcc_cancellation,
      signatureDomain: opts.bccSignatureDomain ?? opts.bcc_signature_domain,
    });
    if (!bccResult.accepted) fail(`bcc_${bccResult.reason}`);
    bccFinalityTags.add(cert.finality.finality_tag);
    checkBccContext(policy, sub, cert);

    settlementTotal += sub.settlement_amount;
    issuedTotal += sub.issued_units;
  }

  if (settlementTotal > policy.max_settlement_amount) fail("settlement_cap_exceeded");
  if (issuedTotal > policy.max_issued_units) fail("issued_cap_exceeded");
  if (pub.settlement_amount_total !== settlementTotal) fail("settlement_total_mismatch");
  if (pub.issued_unit_total !== issuedTotal) fail("issued_total_mismatch");
  if (mint.issued_unit_total !== issuedTotal) fail("mint_total_mismatch");
  if (mint.mint_recipient_set_commitment !== digestHex("aac/fundraise/mint-recipients/1", mint.recipients)) {
    fail("mint_recipient_commitment_mismatch");
  }
  if (pub.mint_recipient_set_commitment !== mint.mint_recipient_set_commitment) {
    fail("public_mint_recipient_mismatch");
  }
  if (pub.subscription_set_commitment !== digestHex("aac/fundraise/subscriptions/1", subscriptions)) {
    fail("subscription_set_commitment_mismatch");
  }

  const transitions = vnetPublic(packet.vnet_link).transition_refs;
  if (pub.transition_set_commitment !== digestHex("aac/fundraise/transitions/1", transitions)) {
    fail("transition_set_commitment_mismatch");
  }
  if (pub.vnet_public_commitment !== digestHex("aac/fundraise/vnet-public/1", vnetPublic(packet.vnet_link))) {
    fail("vnet_public_commitment_mismatch");
  }
  if (pub.bcc_set_commitment !== digestHex("aac/fundraise/bcc-agreements/1", bccAgreements.map(bccPublic))) {
    fail("bcc_set_commitment_mismatch");
  }
  if (pub.bridge_settlement_commitment !== digestHex("aac/fundraise/bridge-settlement/1", bridge)) {
    fail("bridge_settlement_commitment_mismatch");
  }

  const vnet = opts.verifyVnetLink?.(packet.vnet_link) ?? verifyVnetLinkReference(packet.vnet_link);
  if (!vnet.accepted) fail(`vnet_${vnet.reason}`);

  const [debit, credit] = vnetAmountTotals(packet.vnet_link);
  const expected = [settlementTotal, issuedTotal];
  if (!sameVector(debit, expected) || !sameVector(credit, expected)) {
    fail("vnet_amount_total_mismatch");
  }
}

function checkBccContext(policy, sub, cert) {
  const ctx = cert.event?.fundraise_context;
  if (!ctx) fail("bcc_context_missing");
  if (ctx.round_id !== policy.round_id) fail("bcc_round_mismatch");
  if (ctx.subscription_id !== sub.subscription_id) fail("bcc_subscription_mismatch");
  if (ctx.investor_id !== sub.investor_id) fail("bcc_investor_mismatch");
  if (ctx.issuer_name !== policy.issuer_name) fail("bcc_issuer_mismatch");
  if (ctx.settlement_ref !== sub.settlement_ref) fail("bcc_settlement_ref_mismatch");
  if (ctx.settlement_amount !== sub.settlement_amount) fail("bcc_settlement_amount_mismatch");
  if (ctx.issued_units !== sub.issued_units) fail("bcc_issued_units_mismatch");
  if (ctx.token_contract !== policy.token_contract) fail("bcc_token_contract_mismatch");
  const bridge = cert.event?.bridge_context;
  if (!bridge) fail("bcc_bridge_context_missing");
  if (bridge.asset !== policy.settlement_asset_type_id) fail("bcc_bridge_asset_mismatch");
  if (bridge.settlement_chain !== policy.settlement_chain) fail("bcc_bridge_chain_mismatch");
  if (bridge.vault_or_contract !== policy.vault_or_contract) fail("bcc_bridge_contract_mismatch");
  if (bridge.deposit_ref !== sub.settlement_ref) fail("bcc_bridge_deposit_mismatch");
}

export function vnetAmountTotals(vnetLink) {
  const atoms = vnetLink.vnet.atoms;
  const width = atoms[0]?.debit?.length ?? 0;
  const debit = Array(width).fill(0);
  const credit = Array(width).fill(0);
  for (const atom of atoms) {
    for (let i = 0; i < width; i += 1) {
      debit[i] += atom.debit[i];
      credit[i] += atom.credit[i];
    }
  }
  return [debit, credit];
}

function sameVector(a, b) {
  return a.length === b.length && a.every((x, i) => x === b[i]);
}

function fail(reason) {
  throw new FundraiseVerificationError(reason);
}

function isEvmAddress(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{40}$/.test(value);
}

function hex32(value) {
  if (typeof value !== "string") throw new FundraiseVerificationError("bad_bytes32");
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) throw new FundraiseVerificationError("bad_bytes32");
  return `0x${raw.toLowerCase()}`;
}
