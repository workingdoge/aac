import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  authorizeFinality,
  buildBilateralCertificate,
  demoCertificate,
  demoVectors,
  verifyBilateralCertificate,
} from "../src/index.mjs";

function verifyVector(vector) {
  const ctx = vector.verifier_context ?? {};
  const result = verifyBilateralCertificate(vector.certificate, {
    seen_finality_tags: ctx.seen_finality_tags ?? [],
  });
  assert.equal(result.accepted, vector.expect.accepted, `${vector.id} accepted`);
  assert.equal(result.reason, vector.expect.reason, `${vector.id} reason`);
}

const generated = demoVectors();
for (const vector of generated.vectors) verifyVector(vector);

const good = demoCertificate();
const result = verifyBilateralCertificate(good);
assert.equal(result.accepted, true);
assert.equal(result.authorization.finality_tag, good.finality.finality_tag);
assert.equal(authorizeFinality(good).authorization_digest.length, 64);

const rebuilt = buildBilateralCertificate({
  event: good.event,
  records: good.records.map((r) => ({
    party_id: r.party_id,
    role: r.role,
    transition_ref: r.transition_ref,
    journal_commitment: r.journal_commitment,
    basis_type_ids: r.basis_type_ids,
    debit: r.debit,
    credit: r.credit,
    debit_blinding: r.debit_blinding,
    credit_blinding: r.credit_blinding,
  })),
});
assert.equal(verifyBilateralCertificate(rebuilt).accepted, true);

const fixturePath = process.env.BCC_VECTOR_PATH
  ? resolve(process.env.BCC_VECTOR_PATH)
  : resolve(process.env.AAC_REPO_ROOT ?? process.cwd(), "sites/ledger/specs/applications/vectors/BCC-DEMO-1.json");
const fixtureText = await readFile(fixturePath, "utf8").catch(() => "");
if (fixtureText !== "") {
  const fixture = JSON.parse(fixtureText);
  for (const vector of fixture.vectors) verifyVector(vector);
}

console.log("bcc-runtime tests: pass");
