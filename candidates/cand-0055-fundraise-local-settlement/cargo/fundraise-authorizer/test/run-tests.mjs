import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  authorizeFundraisePacket,
  buildSettlementSigningRequest,
  createAuthorizerPolicy,
  SETTLEMENT_SIGNING_REQUEST_SCHEMA,
  settlementDigestWitness,
  signingRequestDigest,
  verifyAuthorizerReceipt,
} from "../src/index.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(here, "../../sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const good = fixture.vectors.find((vector) => vector.id === "fundraise-demo-good").packet;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const policy = createAuthorizerPolicy();
assert.equal(policy.token_contract, "0xAac0000000000000000000000000000000000039");
assert.match(policy.round_id_hash, /^[0-9a-f]{64}$/);

const request = buildSettlementSigningRequest({ packet: good, policy });
assert.equal(request.schema, SETTLEMENT_SIGNING_REQUEST_SCHEMA);
assert.equal(request.chain_id, 12_345);
assert.equal(request.settlement_contract, policy.settlement_contract);
assert.equal(request.contract_authorization.token_contract, policy.token_contract);
assert.equal(request.contract_authorization.round_id_hash, `0x${policy.round_id_hash}`);
assert.equal(request.contract_authorization.issued_unit_total, 150);
assert.deepEqual(
  request.contract_authorization.recipients.map((recipient) => recipient.amount),
  [100, 50],
);
assert.equal(request.settlement_digest_witness, settlementDigestWitness(request));
assert.equal(request.request_digest, signingRequestDigest(request));

const receipt = authorizeFundraisePacket({ packet: good, policy });
assert.equal(receipt.accepted, true);
assert.equal(receipt.request.request_digest, request.request_digest);
assert.equal(verifyAuthorizerReceipt(receipt).accepted, true);

const tokenMismatch = clone(good);
tokenMismatch.mint_authorization.token_contract = "0x0000000000000000000000000000000000000001";
const rejected = authorizeFundraisePacket({ packet: tokenMismatch, policy });
assert.equal(rejected.accepted, false);
assert.equal(rejected.reason, "packet_rejected");
assert.equal(verifyAuthorizerReceipt(rejected).accepted, false);

const badRecipient = authorizeFundraisePacket({
  packet: good,
  policy,
  recipient_overrides: {
    "investor-a": "not-an-address",
  },
});
assert.equal(badRecipient.accepted, false);
assert.equal(badRecipient.reason, "bad_mint_recipient");

const tampered = clone(receipt);
tampered.request.contract_authorization.issued_unit_total += 1;
assert.deepEqual(verifyAuthorizerReceipt(tampered), {
  accepted: false,
  reason: "receipt_digest_mismatch",
});

const badPolicy = authorizeFundraisePacket({
  packet: good,
  policy: { settlement_contract: "not-an-address" },
});
assert.equal(badPolicy.accepted, false);
assert.equal(badPolicy.reason, "policy_invalid");

console.log("fundraise-authorizer tests: pass");
