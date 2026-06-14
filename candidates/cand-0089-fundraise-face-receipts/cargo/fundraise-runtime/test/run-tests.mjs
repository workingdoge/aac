import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  fixtureSignTypedData,
  fixtureProveCancellation,
  fixtureVerifyCancellation,
  fixtureVerifyTypedDataSignature,
  mockSignTranscript,
  transcriptHash,
  buildFinality,
} from "../../bcc-runtime/src/index.mjs";

import {
  authorizeMint,
  buildEvmMintAuthorization,
  buildFundraiseFaceReceipts,
  buildFundraisePacket,
  buildBccAgreements,
  buildBridgeSettlement,
  buildMintAuthorization,
  buildPublicInputs,
  buildSettlementReport,
  createRoundPolicy,
  createSubscription,
  fundraiseFaceForReason,
  verifyFundraisePacket,
} from "../src/index.mjs";

const repoRoot = process.env.AAC_REPO_ROOT ?? process.cwd();
const fixturePath = resolve(repoRoot, "sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const good = fixture.vectors.find((v) => v.id === "fundraise-demo-good").packet;

const fromFixture = verifyFundraisePacket(good);
assert.equal(fromFixture.accepted, true);
assert.equal(fromFixture.authorization.round_id, good.public_inputs.round_id);
assert.equal(fromFixture.authorization.issued_unit_total, 150);

const policy = createRoundPolicy();
const subscriptions = [
  createSubscription({
    subscription_id: "sub-investor-a-001",
    investor_id: "investor-a",
    mint_recipient: "0xA11ce00000000000000000000000000000000039",
    settlement_ref: "arc-usdc-payment:0xa001",
    settlement_amount: 1000,
    issued_units: 100,
    admissibility_ref: "cre-admissibility:investor-a:001",
    subscription_nullifier: "0x31f4f93b6c2e19a001",
  }),
  createSubscription({
    subscription_id: "sub-investor-b-001",
    investor_id: "investor-b",
    mint_recipient: "0xB0b000000000000000000000000000000000039",
    settlement_ref: "arc-usdc-payment:0xb001",
    settlement_amount: 500,
    issued_units: 50,
    admissibility_ref: "cre-admissibility:investor-b:001",
    subscription_nullifier: "0x31f4f93b6c2e19b001",
  }),
];

const rebuilt = buildFundraisePacket({
  policy,
  subscriptions,
  vnetLink: good.vnet_link,
});
assert.deepEqual(rebuilt.settlement_report, buildSettlementReport(policy, subscriptions));
assert.deepEqual(rebuilt.bridge_settlement, buildBridgeSettlement(policy, subscriptions));
assert.deepEqual(rebuilt.mint_authorization, buildMintAuthorization(policy, subscriptions));
assert.equal(verifyFundraisePacket(rebuilt).accepted, true);
assert.equal(rebuilt.bcc_agreements.length, 2);
assert.equal(rebuilt.bcc_agreements[0].certificate.event.fundraise_context.round_id, policy.round_id);
assert.equal(rebuilt.public_inputs.bcc_set_commitment.length, 64);
assert.equal(rebuilt.public_inputs.bridge_settlement_commitment.length, 64);
const faceReceipts = buildFundraiseFaceReceipts(rebuilt);
assert.equal(faceReceipts.schema, "aac.fundraise-runtime.face-receipts.v1");
assert.equal(faceReceipts.profile_id, "FUNDRAISE-CLEARING/1#simplicial-profile");
assert.equal(faceReceipts.accepted, true);
assert.equal(faceReceipts.reason, "accepted");
assert.equal(faceReceipts.failed_face, null);
assert.match(faceReceipts.vertices_commitment, /^[0-9a-f]{64}$/);
assert.match(faceReceipts.edges_commitment, /^[0-9a-f]{64}$/);
assert.match(faceReceipts.faces_commitment, /^[0-9a-f]{64}$/);
assert.deepEqual(faceReceipts.faces.map((face) => face.id), [
  "capacity",
  "payment",
  "agreement",
  "transition",
  "vnet",
  "statement",
  "settlement",
  "nullifier",
]);
assert.ok(faceReceipts.faces.every((face) => face.status === "filled" && face.accepted === true));
assert.equal(faceReceipts.vertices.base_context.entity, policy.issuer_name);
assert.equal(faceReceipts.vertices.subscription_batch.issued_unit_total, 150);
assert.equal(faceReceipts.vertices.issuer_pre_state.balance_sheet_root, rebuilt.public_inputs.prev_balance_sheet_root);
assert.equal(faceReceipts.vertices.receipt_statement.token_contract, policy.token_contract);

const tokenBad = structuredClone(rebuilt);
tokenBad.mint_authorization.token_contract = "0xBad0000000000000000000000000000000000039";
tokenBad.public_inputs.token_contract = tokenBad.mint_authorization.token_contract;
assert.deepEqual(verifyFundraisePacket(tokenBad), { accepted: false, reason: "token_contract_mismatch" });
assert.equal(fundraiseFaceForReason("token_contract_mismatch"), "settlement");
assert.equal(buildFundraiseFaceReceipts(tokenBad).failed_face, "settlement");

const missingBcc = structuredClone(rebuilt);
missingBcc.bcc_agreements.pop();
assert.deepEqual(verifyFundraisePacket(missingBcc), { accepted: false, reason: "bcc_missing" });

const bccSigBad = structuredClone(rebuilt);
bccSigBad.bcc_agreements[0].certificate.signatures[0].signature = "bad-signature";
assert.deepEqual(verifyFundraisePacket(bccSigBad), { accepted: false, reason: "bcc_signature_mismatch" });

const bccReplayBad = structuredClone(rebuilt);
assert.deepEqual(
  verifyFundraisePacket(bccReplayBad, {
    seenBccFinalityTags: new Set([bccReplayBad.bcc_agreements[0].certificate.finality.finality_tag]),
  }),
  { accepted: false, reason: "bcc_finality_replay" },
);
const replayFaces = buildFundraiseFaceReceipts(bccReplayBad, {
  seenBccFinalityTags: new Set([bccReplayBad.bcc_agreements[0].certificate.finality.finality_tag]),
});
assert.equal(replayFaces.failed_face, "agreement");
assert.equal(replayFaces.faces.find((face) => face.id === "agreement").status, "rejected");

const bccRoundBad = structuredClone(rebuilt);
bccRoundBad.bcc_agreements[0] = buildBccAgreements(
  createRoundPolicy({ round_id: "wrong-round" }),
  subscriptions,
  good.vnet_link,
)[0];
assert.deepEqual(verifyFundraisePacket(bccRoundBad), { accepted: false, reason: "bcc_round_mismatch" });

const bridgeAssetBad = structuredClone(rebuilt);
bridgeAssetBad.bridge_settlement.asset_type_id = "EURC:arc-testnet:atomic";
assert.deepEqual(verifyFundraisePacket(bridgeAssetBad), { accepted: false, reason: "bridge_asset_mismatch" });

const eip712Bcc = structuredClone(rebuilt);
for (const agreement of eip712Bcc.bcc_agreements) {
  const cert = agreement.certificate;
  cert.signatures = cert.signatures.map((sig) =>
    fixtureSignTypedData({
      certificate: cert,
      party_id: sig.party_id,
      public_key: sig.public_key,
    }),
  );
}
assert.deepEqual(verifyFundraisePacket(eip712Bcc), { accepted: false, reason: "bcc_signature_verifier_missing" });
assert.equal(verifyFundraisePacket(eip712Bcc, { verifyBccSignature: fixtureVerifyTypedDataSignature }).accepted, true);

const eip712BccBadSigner = structuredClone(eip712Bcc);
eip712BccBadSigner.bcc_agreements[0].certificate.signatures[0].public_key = "wrong-signer";
assert.deepEqual(
  verifyFundraisePacket(eip712BccBadSigner, { verifyBccSignature: fixtureVerifyTypedDataSignature }),
  { accepted: false, reason: "bcc_signature_mismatch" },
);

const vnetCancellationBcc = structuredClone(rebuilt);
for (const agreement of vnetCancellationBcc.bcc_agreements) {
  const cert = agreement.certificate;
  cert.cancellation_opening = fixtureProveCancellation(cert);
  cert.transcript_hash = transcriptHash(cert);
  cert.finality = buildFinality({
    transcript_hash: cert.transcript_hash,
    log_ref: cert.finality.log_ref,
    nullifier: cert.finality.nullifier,
  });
  cert.signatures = cert.records.map((record) =>
    mockSignTranscript({
      party_id: record.party_id,
      public_key: `${record.party_id}:pub`,
      transcript_hash: cert.transcript_hash,
    }),
  );
}
vnetCancellationBcc.public_inputs = buildPublicInputs(
  vnetCancellationBcc.round_policy,
  vnetCancellationBcc.subscriptions,
  vnetCancellationBcc.vnet_link,
  vnetCancellationBcc.mint_authorization,
  vnetCancellationBcc.bcc_agreements,
  vnetCancellationBcc.bridge_settlement,
);
assert.deepEqual(verifyFundraisePacket(vnetCancellationBcc), {
  accepted: false,
  reason: "bcc_cancellation_verifier_missing",
});
assert.equal(
  verifyFundraisePacket(vnetCancellationBcc, { verifyBccCancellation: fixtureVerifyCancellation }).accepted,
  true,
);

const vnetCancellationBad = structuredClone(vnetCancellationBcc);
vnetCancellationBad.bcc_agreements[0].certificate.cancellation_opening.proof_digest = "bad-proof";
assert.deepEqual(
  verifyFundraisePacket(vnetCancellationBad, { verifyBccCancellation: fixtureVerifyCancellation }),
  { accepted: false, reason: "bcc_cancellation_proof_mismatch" },
);

const settlementBad = structuredClone(rebuilt);
settlementBad.settlement_report.accepted.pop();
assert.deepEqual(verifyFundraisePacket(settlementBad), { accepted: false, reason: "settlement_report_missing" });

const priceBad = buildFundraisePacket({
  policy,
  subscriptions: [{ ...subscriptions[0], issued_units: 101 }, subscriptions[1]],
  vnetLink: good.vnet_link,
});
assert.deepEqual(verifyFundraisePacket(priceBad), { accepted: false, reason: "price_mismatch" });
assert.equal(buildFundraiseFaceReceipts(priceBad).failed_face, "capacity");

const vnetBad = structuredClone(rebuilt);
vnetBad.vnet_link.vnet.atoms[0].credit[0] += 1;
assert.deepEqual(verifyFundraisePacket(vnetBad), { accepted: false, reason: "vnet_link_certificate_mismatch" });
assert.equal(buildFundraiseFaceReceipts(vnetBad).failed_face, "vnet");

const vnetPointBad = structuredClone(rebuilt);
vnetPointBad.vnet_link.vnet.atoms[0].debit_commitment.x = "1";
assert.deepEqual(verifyFundraisePacket(vnetPointBad), { accepted: false, reason: "vnet_non_canonical_point_encoding" });

const customVnet = verifyFundraisePacket(vnetPointBad, {
  verifyVnetLink: () => ({ accepted: false, reason: "deployment_verifier_rejected" }),
});
assert.deepEqual(customVnet, { accepted: false, reason: "vnet_deployment_verifier_rejected" });

const duplicateNullifier = buildFundraisePacket({
  policy,
  subscriptions: [
    subscriptions[0],
    { ...subscriptions[1], subscription_nullifier: subscriptions[0].subscription_nullifier },
  ],
  vnetLink: good.vnet_link,
});
assert.deepEqual(verifyFundraisePacket(duplicateNullifier), { accepted: false, reason: "duplicate_nullifier" });
assert.equal(buildFundraiseFaceReceipts(duplicateNullifier).failed_face, "nullifier");

const authorized = authorizeMint(rebuilt);
assert.equal(authorized.schema, "aac.fundraise-runtime.authorized-mint.v1");
assert.equal(authorized.token_contract, policy.token_contract);
assert.equal(authorized.issued_unit_total, 150);
assert.equal(typeof authorized.authorization_digest, "string");
assert.equal(authorized.authorization_digest.length, 64);
assert.equal(authorized.recipients.length, 2);

const evmToken = "0xAac0000000000000000000000000000000000039";
assert.throws(() => buildEvmMintAuthorization(authorized), /bad_token_contract/);
const evmReadyAuthorized = structuredClone(authorized);
evmReadyAuthorized.recipients[0].recipient = "0x00000000000000000000000000000000000A11CE";
evmReadyAuthorized.recipients[1].recipient = "0x0000000000000000000000000000000000000B0B";
const evmAuth = buildEvmMintAuthorization(evmReadyAuthorized, { tokenContract: evmToken });
assert.equal(evmAuth.schema, "aac.fundraise-runtime.evm-mint-authorization.v1");
assert.equal(evmAuth.runtime_authorization_digest, `0x${authorized.authorization_digest}`);
assert.equal(evmAuth.runtime_mint_recipient_set_commitment, `0x${authorized.mint_recipient_set_commitment}`);
assert.equal(evmAuth.token_contract, evmToken);
assert.equal(evmAuth.issued_unit_total, authorized.issued_unit_total);
assert.deepEqual(evmAuth.recipients, [
  { account: "0x00000000000000000000000000000000000A11CE", amount: 100 },
  { account: "0x0000000000000000000000000000000000000B0B", amount: 50 },
]);

const badRecipientAuth = structuredClone(authorized);
badRecipientAuth.recipients[0].recipient = "not-an-address";
assert.throws(() => buildEvmMintAuthorization(badRecipientAuth, { tokenContract: evmToken }), /bad_mint_recipient/);

console.log("fundraise-runtime tests: pass");
