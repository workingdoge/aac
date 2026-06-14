import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildProveKitVerifierReceipt,
  normalizeProveKitResult,
  verifyProveKitVerifierReceipt,
} from "../src/index.mjs";
import {
  authorizeFundraiseWorkflow,
  createWorkflowPolicy,
  verifyWorkflowReceipt,
} from "../../fundraise-workflow/src/index.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(here, "../../sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const packet = fixture.vectors.find((vector) => vector.id === "fundraise-demo-good").packet;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const provekit = {
  accepted: true,
  proof_system: "provekit-whir",
  mode: "native-cli",
  proof: new Uint8Array([1, 2, 3, 4]),
  public_inputs: packet.public_inputs,
  verifier_key_digest: "0x" + "ab".repeat(32),
  timings_ms: { prove: 400, verify: 40 },
};

const normalized = normalizeProveKitResult(provekit);
assert.equal(normalized.proof_system, "provekit-whir");
assert.equal(normalized.mode, "native-cli");
assert.match(normalized.proof_digest, /^0x[0-9a-f]{64}$/);
assert.equal(normalized.verifier_key_digest, "0x" + "ab".repeat(32));

const receipt = buildProveKitVerifierReceipt({ packet, provekit });
assert.equal(receipt.accepted, true);
assert.equal(receipt.proof_system, "provekit-whir");
assert.equal(receipt.mode, "native-cli");
assert.equal(verifyProveKitVerifierReceipt(receipt, { packet }).accepted, true);

const policy = createWorkflowPolicy({ require_live_proof: true });
const workflow = authorizeFundraiseWorkflow({ packet, verifier_receipt: receipt, policy });
assert.equal(workflow.accepted, true);
assert.equal(workflow.settlement_action.args.auth.issued_unit_total, 150);
assert.equal(verifyWorkflowReceipt(workflow).accepted, true);

assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, accepted: false, reason: "bad proof" } }),
  /bad proof/,
);
assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, proof_system: "runtime-reference" } }),
  /bad_proof_system/,
);
assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, verifier_key_digest: "0x1234" } }),
  /bad_verifier_key_digest/,
);

const tampered = clone(receipt);
tampered.proof_digest = "0x" + "11".repeat(32);
assert.equal(verifyProveKitVerifierReceipt(tampered, { packet }).reason, "verifier_receipt_digest_mismatch");

const stalePacket = clone(packet);
stalePacket.public_inputs.issued_unit_total += 1;
assert.equal(verifyProveKitVerifierReceipt(receipt, { packet: stalePacket }).reason, "verifier_packet_mismatch");

console.log("fundraise-provekit-adapter tests: pass");
