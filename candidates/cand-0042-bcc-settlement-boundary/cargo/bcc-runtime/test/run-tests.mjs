import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  authorizeFinality,
  buildBilateralCertificate,
  buildBilateralPacket,
  demoCertificate,
  demoPacket,
  demoVectors,
  verifyBilateralCertificate,
  verifyBilateralPacket,
} from "../src/index.mjs";

function verifyVector(vector) {
  const ctx = vector.verifier_context ?? {};
  const result = verifyBilateralCertificate(vector.certificate, {
    seen_finality_tags: ctx.seen_finality_tags ?? [],
  });
  assert.equal(result.accepted, vector.expect.accepted, `${vector.id} accepted`);
  assert.equal(result.reason, vector.expect.reason, `${vector.id} reason`);
  if (vector.expect.accepted && vector.private_witness) {
    const packetResult = verifyBilateralPacket({
      schema: "aac.bcc.packet.v1",
      certificate: vector.certificate,
      private_witness: vector.private_witness,
    });
    assert.equal(packetResult.accepted, true, `${vector.id} packet accepted`);
  }
}

const generated = demoVectors();
for (const vector of generated.vectors) verifyVector(vector);

const good = demoCertificate();
const result = verifyBilateralCertificate(good);
assert.equal(result.accepted, true);
assert.equal(result.authorization.finality_tag, good.finality.finality_tag);
assert.equal(result.authorization.settlement_boundary, "agreement-certificate-only");
assert.equal(authorizeFinality(good).authorization_digest.length, 64);
assert.equal("debit" in good.records[0], false);
assert.equal("credit" in good.records[0], false);
assert.equal("record_blinding" in good.records[0], false);

const goodPacket = demoPacket();
assert.equal(verifyBilateralPacket(goodPacket).accepted, true);
assert.equal(goodPacket.private_witness.records[0].debit[0], 3);

const rebuiltPacket = buildBilateralPacket({
  event: good.event,
  records: goodPacket.private_witness.records.map((r, i) => ({
    party_id: r.party_id,
    role: r.role,
    transition_ref: good.records[i].transition_ref,
    journal_commitment: good.records[i].journal_commitment,
    basis_type_ids: r.basis_type_ids,
    debit: r.debit,
    credit: r.credit,
    record_blinding: r.record_blinding,
  })),
});
assert.equal(verifyBilateralCertificate(rebuiltPacket.certificate).accepted, true);
assert.equal(verifyBilateralPacket(rebuiltPacket).accepted, true);

const certOnly = buildBilateralCertificate({
  event: good.event,
  records: goodPacket.private_witness.records.map((r, i) => ({
    party_id: r.party_id,
    role: r.role,
    transition_ref: good.records[i].transition_ref,
    journal_commitment: good.records[i].journal_commitment,
    basis_type_ids: r.basis_type_ids,
    debit: r.debit,
    credit: r.credit,
    record_blinding: r.record_blinding,
  })),
});
assert.equal(verifyBilateralCertificate(certOnly).accepted, true);

const fixturePath = process.env.BCC_VECTOR_PATH
  ? resolve(process.env.BCC_VECTOR_PATH)
  : resolve(process.env.AAC_REPO_ROOT ?? process.cwd(), "sites/ledger/specs/applications/vectors/BCC-DEMO-1.json");
const fixtureText = await readFile(fixturePath, "utf8").catch(() => "");
if (fixtureText !== "") {
  const fixture = JSON.parse(fixtureText);
  for (const vector of fixture.vectors) verifyVector(vector);
}

console.log("bcc-runtime tests: pass");
