import { createHash } from "node:crypto";

export const PROFILE_ID = "vnet-bn254-g1/1";
export const VECTOR_SCHEMA = "aac.vnet-bn254-g1.conformance.v1";
export const LINK_SCHEMA = "aac.vnet-link-ref.conformance.v1";

export const P = 21888242871839275222246405745257275088696311157297823662689037894645226208583n;
export const R = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const INF = null;
const U64_BOUND = 1n << 64n;

export class VnetVerificationError extends Error {
  constructor(reason, message = reason) {
    super(message);
    this.name = "VnetVerificationError";
    this.reason = reason;
  }
}

export function canonical(value) {
  return JSON.stringify(sortCanonical(value));
}

export function digestHex(label, ...parts) {
  return createHash("sha256").update(canonical([label, ...parts])).digest("hex");
}

export function scalarHash(label, ...parts) {
  return BigInt(`0x${digestHex(label, ...parts)}`) % R;
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

function mod(x, m = P) {
  const out = x % m;
  return out >= 0n ? out : out + m;
}

function powMod(base, exp, m = P) {
  let b = mod(base, m);
  let e = exp;
  let out = 1n;
  while (e > 0n) {
    if (e & 1n) out = (out * b) % m;
    b = (b * b) % m;
    e >>= 1n;
  }
  return out;
}

function inv(x) {
  return powMod(x, P - 2n, P);
}

function isSquare(x) {
  const n = mod(x);
  return n === 0n || powMod(n, (P - 1n) / 2n, P) === 1n;
}

function sqrtEven(x) {
  const y = powMod(x, (P + 1n) / 4n, P);
  if ((y * y) % P !== mod(x)) throw new VnetVerificationError("not_square");
  return y % 2n === 0n ? y : P - y;
}

function isOnCurve(pt) {
  if (pt === INF) return true;
  const [x, y] = pt;
  return x >= 0n && x < P && y >= 0n && y < P && mod(y * y - x * x * x - 3n) === 0n;
}

function pointEq(a, b) {
  if (a === INF || b === INF) return a === b;
  return a[0] === b[0] && a[1] === b[1];
}

function add(a, b) {
  if (a === INF) return b;
  if (b === INF) return a;
  const [x1, y1] = a;
  const [x2, y2] = b;
  if (x1 === x2 && mod(y1 + y2) === 0n) return INF;
  const lam = pointEq(a, b)
    ? mod(3n * x1 * x1 * inv(2n * y1))
    : mod((y2 - y1) * inv(x2 - x1));
  const x3 = mod(lam * lam - x1 - x2);
  const y3 = mod(lam * (x1 - x3) - y1);
  return [x3, y3];
}

function neg(pt) {
  if (pt === INF) return INF;
  return [pt[0], mod(-pt[1])];
}

function mul(k, pt) {
  let scalar = mod(toBigInt(k), R);
  let out = INF;
  let cur = pt;
  while (scalar > 0n) {
    if (scalar & 1n) out = add(out, cur);
    cur = add(cur, cur);
    scalar >>= 1n;
  }
  return out;
}

function h2c(label, ...parts) {
  const base = Buffer.from(canonical([label, ...parts]));
  for (let counter = 0; counter < 1_000_000; counter += 1) {
    const c = Buffer.alloc(4);
    c.writeUInt32BE(counter);
    const digest = createHash("sha256").update(Buffer.concat([base, c])).digest();
    const x = BigInt(`0x${digest.toString("hex")}`) % P;
    const rhs = mod(x ** 3n + 3n);
    if (isSquare(rhs)) return [x, sqrtEven(rhs)];
  }
  throw new VnetVerificationError("hash_to_curve_failed");
}

export function basisCommitment(basisTypeIds) {
  return scalarHash("aac/vnet-bn254-g1/1/basis", PROFILE_ID, basisTypeIds).toString();
}

function generators(basisTypeIds) {
  const bc = basisCommitment(basisTypeIds);
  const h = h2c("aac/vnet-bn254-g1/1/H", PROFILE_ID, bc);
  const gs = basisTypeIds.map((id, i) => h2c("aac/vnet-bn254-g1/1/G", PROFILE_ID, bc, i, id));
  return { h, gs, basis_commitment: bc };
}

export function encodePoint(pt) {
  if (pt === INF) throw new VnetVerificationError("point_at_infinity");
  const [x, y] = pt;
  return {
    x: x.toString(),
    y: y.toString(),
    uncompressed: `0x04${x.toString(16).padStart(64, "0")}${y.toString(16).padStart(64, "0")}`,
  };
}

export function decodePoint(obj) {
  if (!obj || typeof obj !== "object") throw new VnetVerificationError("point_missing");
  const x = toBigInt(obj.x);
  const y = toBigInt(obj.y);
  const enc = `0x04${x.toString(16).padStart(64, "0")}${y.toString(16).padStart(64, "0")}`;
  if (obj.uncompressed !== enc) throw new VnetVerificationError("non_canonical_point_encoding");
  const pt = [x, y];
  if (!isOnCurve(pt)) throw new VnetVerificationError("point_not_on_curve");
  if (mul(R, pt) !== INF) throw new VnetVerificationError("point_not_in_subgroup");
  return pt;
}

export function commitVector(vec, rho, basisTypeIds) {
  const { h, gs } = generators(basisTypeIds);
  let acc = mul(toBigInt(rho), h);
  vec.forEach((amount, i) => {
    const n = toBigInt(amount);
    if (n < 0n || n >= U64_BOUND) throw new VnetVerificationError("amount_out_of_profile_bound");
    acc = add(acc, mul(n, gs[i]));
  });
  if (acc === INF) throw new VnetVerificationError("commitment_is_infinity");
  return acc;
}

export function foldScalar(label, items) {
  return scalarHash(label, items).toString();
}

export function verifyVnetBn254Vector(vnet) {
  try {
    checkVnetBn254Vector(vnet);
    return { accepted: true, reason: "accepted" };
  } catch (err) {
    if (err instanceof VnetVerificationError) return { accepted: false, reason: err.reason };
    throw err;
  }
}

function checkVnetBn254Vector(vnet) {
  if (vnet?.profile_id !== PROFILE_ID) fail("profile_id");
  const commonBasis = vnet.basis_type_ids;
  if (!Array.isArray(commonBasis) || commonBasis.length === 0) fail("basis_type_ids");
  const commonBc = basisCommitment(commonBasis);
  if (vnet.basis_commitment !== commonBc) fail("basis_commitment");

  for (const atom of vnet.atoms ?? []) {
    if (atom.profile_id !== PROFILE_ID) fail("profile_id");
    if (atom.basis_commitment !== commonBc || !sameArray(atom.basis_type_ids, commonBasis)) fail("mixed_basis");
    if (atom.transition_link?.opening_matches_journal !== true) fail("missing_transition_link");
    if (!pointEq(decodePoint(atom.debit_commitment), commitVector(atom.debit, atom.debit_blinding, commonBasis))) {
      fail("commitment_mismatch");
    }
    if (!pointEq(decodePoint(atom.credit_commitment), commitVector(atom.credit, atom.credit_blinding, commonBasis))) {
      fail("commitment_mismatch");
    }
  }

  const expectedTransitionSet = foldScalar(
    "aac/vnet-bn254-g1/1/transition-set",
    vnet.atoms.map((atom) => [atom.transition_ref, atom.journal_commitment]),
  );
  const expectedCommitmentSet = foldScalar(
    "aac/vnet-bn254-g1/1/commitment-set",
    vnet.atoms.map((atom) => [atom.debit_commitment, atom.credit_commitment, atom.basis_commitment]),
  );
  if (vnet.transition_set_commitment !== expectedTransitionSet) fail("transition_set_commitment");
  if (vnet.commitment_set_commitment !== expectedCommitmentSet) fail("commitment_set_commitment");

  let aggregate = INF;
  let aggregateBlind = 0n;
  let debits = Array(commonBasis.length).fill(0n);
  let credits = Array(commonBasis.length).fill(0n);
  for (const atom of vnet.atoms) {
    const cd = decodePoint(atom.debit_commitment);
    const cc = decodePoint(atom.credit_commitment);
    aggregate = add(add(aggregate, cd), neg(cc));
    aggregateBlind = mod(aggregateBlind + toBigInt(atom.debit_blinding) - toBigInt(atom.credit_blinding), R);
    debits = debits.map((n, i) => n + toBigInt(atom.debit[i]));
    credits = credits.map((n, i) => n + toBigInt(atom.credit[i]));
  }
  if (!pointEq(decodePoint(vnet.aggregate_opening), aggregate)) fail("aggregate_opening");
  const { h } = generators(commonBasis);
  if (!pointEq(aggregate, mul(aggregateBlind, h)) || vnet.aggregate_blinding !== aggregateBlind.toString()) {
    fail("zero_opening");
  }
  if (!sameArray(debits.map(String), credits.map(String))) fail("pn_balance");
}

export function certificateFor(atom) {
  const body = {
    transition_ref: atom.transition_ref,
    journal_commitment: atom.journal_commitment,
    profile_id: atom.profile_id,
    basis_commitment: atom.basis_commitment,
    basis_type_ids: [...atom.basis_type_ids],
    debit: [...atom.debit],
    credit: [...atom.credit],
  };
  return {
    ...body,
    certificate_hash: digestHex("aac/vnet-link-ref/1", body),
  };
}

export function transitionReportFor(vnet) {
  return {
    schema: "aac.vnet-link-ref.transition-report.v1",
    accepted: vnet.atoms.map((atom) => ({
      transition_ref: atom.transition_ref,
      target: "TRANSITION/1",
      journal_commitment: atom.journal_commitment,
    })),
  };
}

export function verifyVnetLink(vnetLink) {
  try {
    checkVnetLink(vnetLink);
    return { accepted: true, reason: "accepted" };
  } catch (err) {
    if (err instanceof VnetVerificationError) return { accepted: false, reason: err.reason };
    throw err;
  }
}

function checkVnetLink(vnetLink) {
  const report = new Map((vnetLink?.transition_report?.accepted ?? []).map((item) => [item.transition_ref, item]));
  const certs = new Map((vnetLink?.link_certificates ?? []).map((item) => [item.transition_ref, item]));

  for (const atom of vnetLink?.vnet?.atoms ?? []) {
    const reported = report.get(atom.transition_ref);
    if (!reported) fail("missing_transition_ref");
    if (reported.target !== "TRANSITION/1") fail("wrong_transition_target");
    if (reported.journal_commitment !== atom.journal_commitment) fail("journal_commitment_mismatch");

    const cert = certs.get(atom.transition_ref);
    if (!cert) fail("missing_link_certificate");
    if (canonical(cert) !== canonical(certificateFor(atom))) fail("link_certificate_mismatch");
  }

  const profile = verifyVnetBn254Vector(vnetLink.vnet);
  if (!profile.accepted) fail(profile.reason);
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

function toBigInt(value) {
  if (typeof value === "bigint") return value;
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new VnetVerificationError("bad_integer");
    return BigInt(value);
  }
  if (typeof value === "string" && /^-?[0-9]+$/.test(value)) return BigInt(value);
  throw new VnetVerificationError("bad_integer");
}

function sameArray(a, b) {
  return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => x === b[i]);
}

function fail(reason) {
  throw new VnetVerificationError(reason);
}
