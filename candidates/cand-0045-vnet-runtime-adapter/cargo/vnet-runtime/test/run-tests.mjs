import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  basisCommitment,
  certificateFor,
  verifyVnetBn254Vector,
  verifyVnetLink,
} from "../src/index.mjs";

const repoRoot = process.env.AAC_REPO_ROOT ?? process.cwd();
const profilePath = resolve(repoRoot, "sites/ledger/specs/profiles/vectors/VNET-BN254-G1-1.json");
const linkPath = resolve(repoRoot, "sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json");

const profileFixture = JSON.parse(await readFile(profilePath, "utf8"));
for (const vector of profileFixture.vectors) {
  const result = verifyVnetBn254Vector(vector);
  assert.equal(result.accepted, vector.expect.accepted, `${vector.id} accepted`);
  assert.equal(result.reason, vector.expect.reason, `${vector.id} reason`);
}

const linkFixture = JSON.parse(await readFile(linkPath, "utf8"));
for (const vector of linkFixture.vectors) {
  const result = verifyVnetLink(vector);
  assert.equal(result.accepted, vector.expect.accepted, `${vector.id} accepted`);
  assert.equal(result.reason, vector.expect.reason, `${vector.id} reason`);
}

const good = linkFixture.vectors.find((v) => v.id === "vnet-link-good-fundraise");
assert.equal(basisCommitment(good.vnet.basis_type_ids), good.vnet.basis_commitment);
assert.deepEqual(certificateFor(good.vnet.atoms[0]), good.link_certificates[0]);

const pointBad = structuredClone(good);
pointBad.vnet.atoms[0].debit_commitment.x = "1";
assert.deepEqual(verifyVnetLink(pointBad), { accepted: false, reason: "non_canonical_point_encoding" });

const zeroBad = structuredClone(good);
zeroBad.vnet.aggregate_blinding = "2";
assert.deepEqual(verifyVnetLink(zeroBad), { accepted: false, reason: "zero_opening" });

console.log("vnet-runtime tests: pass");
