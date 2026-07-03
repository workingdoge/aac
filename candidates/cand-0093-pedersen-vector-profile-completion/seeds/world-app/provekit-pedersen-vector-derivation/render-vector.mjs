#!/usr/bin/env node
import { readFileSync } from "node:fs";

function fieldOf(s) {
  const bytes = Buffer.from(s, "utf8");
  let out = 0n;
  for (const byte of bytes) out = (out << 8n) + BigInt(byte);
  return { string: s, byte_length: bytes.length, field: out.toString(), hex: `0x${out.toString(16)}` };
}

function point(label, j, basisTypeId, seed, ctr, x, y, rejectedPriorCounters = []) {
  return {
    label,
    j,
    basis_type_id_j: basisTypeId,
    seed: { field: BigInt(seed).toString(), hex: seed },
    accepted_ctr: Number(BigInt(ctr)),
    point: {
      x: BigInt(x).toString(),
      y: BigInt(y).toString(),
      x_hex: x,
      y_hex: y,
      is_infinite: false,
    },
    rejected_prior_counters: rejectedPriorCounters,
  };
}

const nargoOutput = readFileSync(0, "utf8");
const match = nargoOutput.match(/Circuit output: \[(.*)\]/s);
if (!match) {
  process.stderr.write(nargoOutput);
  throw new Error("could not parse nargo circuit output");
}

const fields = match[1].split(",").map((s) => s.trim());
if (fields.length !== 22) throw new Error(`expected 22 fields, got ${fields.length}`);

const [
  basisCommitment,
  hSeed,
  g0Seed,
  g1Seed,
  g2Seed,
  hCtr,
  hX,
  hY,
  g0Ctr,
  g0X,
  g0Y,
  g1Ctr,
  g1X,
  g1Y,
  g2Ctr,
  g2X,
  g2Y,
  g1RejectX0,
  g1RejectX1,
  g1RejectX2,
  g2RejectX0,
  g2RejectX1,
] = fields;

const vector = {
  schema: "aac.pedersen-vector.derivation.v1",
  profile_id: "pedersen-vector/1",
  description: "PEDERSEN-VECTOR/1 Grumpkin generator derivation for the 3-dimensional VNET demo basis.",
  toolchain: {
    noir: "v1.0.0-beta.19",
    package: "world-app/provekit-pedersen-vector-derivation",
    hash: "Noir stdlib std::hash::poseidon2_permutation, width 4/rate 3 sponge with message length in the capacity lane",
  },
  field_of: {
    rule: "UTF-8 bytes interpreted as a big-endian integer; byte length must be <= 31; no reduction.",
    values: [
      fieldOf("aac/vnet/1"),
      fieldOf("aac/vnet/1/basis"),
      fieldOf("pedersen-vector/1"),
      fieldOf("G"),
      fieldOf("H"),
      fieldOf("USD"),
      fieldOf("fabric"),
      fieldOf("shares"),
    ],
  },
  basis: {
    n: 3,
    basis_type_ids: ["USD", "fabric", "shares"],
    basis_commitment: {
      field: BigInt(basisCommitment).toString(),
      hex: basisCommitment,
      formula: "Poseidon2(field_of(\"aac/vnet/1/basis\"), field_of(profile_id), n, field_of(basis_type_id_0), field_of(basis_type_id_1), field_of(basis_type_id_2))",
    },
  },
  curve: {
    name: "Grumpkin",
    base_field: "21888242871839275222246405745257275088548364400416034343698204186575808495617",
    equation: "y^2 = x^3 - 17",
    canonical_y: "even square root",
  },
  generators: [
    point("H", 0, "USD", hSeed, hCtr, hX, hY),
    point("G", 0, "USD", g0Seed, g0Ctr, g0X, g0Y),
    point("G", 1, "fabric", g1Seed, g1Ctr, g1X, g1Y, [
      { ctr: 0, x_hex: g1RejectX0, legendre: "-1" },
      { ctr: 1, x_hex: g1RejectX1, legendre: "-1" },
      { ctr: 2, x_hex: g1RejectX2, legendre: "-1" },
    ]),
    point("G", 2, "shares", g2Seed, g2Ctr, g2X, g2Y, [
      { ctr: 0, x_hex: g2RejectX0, legendre: "-1" },
      { ctr: 1, x_hex: g2RejectX1, legendre: "-1" },
    ]),
  ],
  notes: [
    "Generated with the Noir beta.19 stdlib Poseidon2 permutation, the same implementation family used by the ProveKit VNET circuit.",
    "These vectors pin the PEDERSEN-VECTOR/1 derivation rule; they are not yet an independent Poseidon2 implementation cross-check.",
    "An independent Python Poseidon2 cross-check is intentionally queued as follow-up work.",
  ],
};

process.stdout.write(`${JSON.stringify(vector, null, 2)}\n`);
