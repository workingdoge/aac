import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  authorizeFundraiseWorkflow,
  buildDemoVerifierReceipt,
  createWorkflowPolicy,
  packetCommitment,
  verifyVerifierReceipt,
  verifyWorkflowReceipt,
  WORKFLOW_RECEIPT_SCHEMA,
} from "../src/index.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(here, "../../sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const packet = fixture.vectors.find((vector) => vector.id === "fundraise-demo-good").packet;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const verifier = buildDemoVerifierReceipt({ packet });
assert.equal(verifier.accepted, true);
assert.equal(verifier.packet_commitment, packetCommitment(packet));
assert.equal(verifyVerifierReceipt(verifier, { packet }).accepted, true);

const receipt = authorizeFundraiseWorkflow({ packet, verifier_receipt: verifier });
assert.equal(receipt.schema, WORKFLOW_RECEIPT_SCHEMA);
assert.equal(receipt.accepted, true);
assert.equal(receipt.settlement_action.method, "settle");
assert.equal(receipt.settlement_action.args.signature, null);
assert.equal(receipt.settlement_action.args.auth.issued_unit_total, 150);
assert.equal(receipt.settlement_action.args.auth.recipients.length, 2);
assert.equal(receipt.authorization_receipt.accepted, true);
assert.equal(verifyWorkflowReceipt(receipt).accepted, true);

const livePolicy = createWorkflowPolicy({
  require_live_proof: true,
  accepted_proof_systems: ["runtime-reference", "provekit-whir"],
});
const liveRejected = authorizeFundraiseWorkflow({
  packet,
  verifier_receipt: verifier,
  policy: livePolicy,
});
assert.equal(liveRejected.accepted, false);
assert.equal(liveRejected.reason, "live_proof_required");

const wrongPacket = clone(packet);
wrongPacket.public_inputs.issued_unit_total += 1;
const packetRejected = authorizeFundraiseWorkflow({
  packet: wrongPacket,
  verifier_receipt: verifier,
});
assert.equal(packetRejected.accepted, false);
assert.equal(packetRejected.reason, "verifier_packet_mismatch");

const badVerifier = clone(verifier);
badVerifier.proof_system = "unknown-proof-system";
assert.equal(verifyVerifierReceipt(badVerifier, { packet }).reason, "verifier_receipt_digest_mismatch");

const rejectedVerifier = clone(verifier);
rejectedVerifier.accepted = false;
rejectedVerifier.reason = "provekit_rejected";
rejectedVerifier.receipt_digest = buildDemoVerifierReceipt({ packet }).receipt_digest;
assert.equal(verifyVerifierReceipt(rejectedVerifier, { packet }).reason, "verifier_receipt_digest_mismatch");

const tampered = clone(receipt);
tampered.settlement_action.args.auth.issued_unit_total += 1;
assert.deepEqual(verifyWorkflowReceipt(tampered), {
  accepted: false,
  reason: "workflow_receipt_digest_mismatch",
});

console.log("fundraise-workflow tests: pass");
