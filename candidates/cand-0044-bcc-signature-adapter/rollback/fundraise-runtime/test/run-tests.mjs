import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  authorizeMint,
  buildFundraisePacket,
  buildBccAgreements,
  buildBridgeSettlement,
  buildMintAuthorization,
  buildSettlementReport,
  createRoundPolicy,
  createSubscription,
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

const tokenBad = structuredClone(rebuilt);
tokenBad.mint_authorization.token_contract = "0xBad0000000000000000000000000000000000039";
tokenBad.public_inputs.token_contract = tokenBad.mint_authorization.token_contract;
assert.deepEqual(verifyFundraisePacket(tokenBad), { accepted: false, reason: "token_contract_mismatch" });

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

const settlementBad = structuredClone(rebuilt);
settlementBad.settlement_report.accepted.pop();
assert.deepEqual(verifyFundraisePacket(settlementBad), { accepted: false, reason: "settlement_report_missing" });

const priceBad = buildFundraisePacket({
  policy,
  subscriptions: [{ ...subscriptions[0], issued_units: 101 }, subscriptions[1]],
  vnetLink: good.vnet_link,
});
assert.deepEqual(verifyFundraisePacket(priceBad), { accepted: false, reason: "price_mismatch" });

const vnetBad = structuredClone(rebuilt);
vnetBad.vnet_link.vnet.atoms[0].credit[0] += 1;
assert.deepEqual(verifyFundraisePacket(vnetBad), { accepted: false, reason: "vnet_zero_opening" });

const authorized = authorizeMint(rebuilt);
assert.equal(authorized.schema, "aac.fundraise-runtime.authorized-mint.v1");
assert.equal(authorized.token_contract, policy.token_contract);
assert.equal(authorized.issued_unit_total, 150);
assert.equal(typeof authorized.authorization_digest, "string");
assert.equal(authorized.authorization_digest.length, 64);
assert.equal(authorized.recipients.length, 2);

console.log("fundraise-runtime tests: pass");
