import { createHash } from "node:crypto";
import { digestHex } from "../../fundraise-runtime/src/index.mjs";

export const PROVEKIT_VNET_PACKET_BINDING_SCHEMA =
  "aac.fundraise-demo-runner.vnet-provekit-packet-binding.v1";

export const PROVEKIT_VNET_PROFILE_ID = "pedersen-vector/1";
export const PROVEKIT_VNET_BASIS = Object.freeze(["USD", "fabric", "shares"]);
export const PROVEKIT_VNET_N_ATOMS = 2;
export const PROVEKIT_VNET_N_BASIS = 3;
export const PROVEKIT_VNET_N_TRANSITION_ROWS = 4;
export const PROVEKIT_VNET_N_ACCT = 4;
export const PROVEKIT_VNET_MAX_COORD = 1_000_000_000_000n;

const FIELD_MODULUS =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const GRUMPKIN_B =
  21888242871839275222246405745257275088548364400416034343698204186575808495600n;
const PROFILE_ID_FIELD = 38246398409996331787205124593264425578289n;
const BASIS_COMMITMENT_FIELD =
  3199263021048886800067584263637418741171169451581946816529327257071282393363n;
const SAMPLE_CONTEXT_COMMITMENT = 9001n;

const H = [
  4442116937809428038466015586910822967980340166078939661906387952790413686754n,
  4817294039429267488105969530543855969668900749954483897040948903322607393472n,
];
const G = [
  [
    21378867110033115454839947600763369042167635625733880473869229047765030521928n,
    8543745247798408310630292543307850943452724989093895241541507109679289712694n,
  ],
  [
    15744486407527661081054625781727663178874265897862468867830629516418152836222n,
    1205556853403814078068855613005326727425376491567528311964745933406350166466n,
  ],
  [
    6215747075525991822894217274899096128320508540089587382936458111022554489410n,
    17447054944361757926801073249828699265838738136270834167682343104825010839236n,
  ],
];

export class ProveKitVnetPacketBindingError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "ProveKitVnetPacketBindingError";
    this.reason = reason;
    this.detail = detail;
  }
}

export function buildProveKitVnetWitnessFromPacket(packet) {
  const vnet = packet?.vnet_link?.vnet;
  if (!vnet || typeof vnet !== "object") {
    fail("vnet_provekit_link_missing");
  }
  assertProfileAndBasis(vnet);
  const atoms = Array.isArray(vnet.atoms) ? vnet.atoms : [];
  if (atoms.length !== PROVEKIT_VNET_N_ATOMS) {
    fail("vnet_provekit_atom_count_mismatch", {
      expected: PROVEKIT_VNET_N_ATOMS,
      actual: atoms.length,
    });
  }

  const normalizedAtoms = atoms.map((atom, index) => normalizeAtom(atom, index));
  const aggregate = aggregateOpening(normalizedAtoms);
  const expectedAggregate = normalizePoint(vnet.aggregate_opening, "vnet.aggregate_opening");
  assertSamePoint(aggregate, expectedAggregate, "vnet_provekit_aggregate_opening_mismatch");
  assertZeroNet(normalizedAtoms);

  const publicInputs = {
    profile_id_pub: fieldString(PROFILE_ID_FIELD),
    basis_commitment_pub: fieldString(BASIS_COMMITMENT_FIELD),
    transition_set_commitment_pub: fieldString(parseField(
      vnet.transition_set_commitment,
      "vnet_provekit_transition_set_missing",
      "vnet.transition_set_commitment",
    )),
    commitment_set_commitment_pub: fieldString(parseField(
      vnet.commitment_set_commitment,
      "vnet_provekit_commitment_set_missing",
      "vnet.commitment_set_commitment",
    )),
    aggregate_opening_x_pub: fieldString(aggregate[0]),
    aggregate_opening_y_pub: fieldString(aggregate[1]),
    atom_count_pub: fieldString(BigInt(PROVEKIT_VNET_N_ATOMS)),
    context_commitment_pub: fieldString(normalizeContextCommitment(vnet)),
  };
  const privateInputs = {
    transition_refs: normalizedAtoms.map((atom) => fieldString(atom.transition_ref)),
    journal_commitments: normalizedAtoms.map((atom) => fieldString(atom.journal_commitment)),
    transition_accounts: normalizedAtoms.map((atom) => atom.transition_accounts.map(fieldString)),
    transition_debits: normalizedAtoms.map((atom) =>
      atom.transition_debits.map((row) => row.map(fieldString))),
    transition_credits: normalizedAtoms.map((atom) =>
      atom.transition_credits.map((row) => row.map(fieldString))),
    debit: normalizedAtoms.map((atom) => atom.debit.map(fieldString)),
    credit: normalizedAtoms.map((atom) => atom.credit.map(fieldString)),
    r_debit: normalizedAtoms.map((atom) => fieldString(atom.r_debit)),
    r_credit: normalizedAtoms.map((atom) => fieldString(atom.r_credit)),
  };
  const proverToml = renderProveKitVnetProverToml(publicInputs, privateInputs);
  const witness = {
    schema: PROVEKIT_VNET_PACKET_BINDING_SCHEMA,
    profile_id: PROVEKIT_VNET_PROFILE_ID,
    basis_type_ids: [...PROVEKIT_VNET_BASIS],
    public_inputs: publicInputs,
    private_inputs: privateInputs,
    prover_toml: proverToml,
    packet_vnet_link_commitment: hex32(digestHex(
      "aac/fundraise-demo-runner/vnet-link/1",
      packet.vnet_link,
    )),
    public_inputs_commitment: hex32(digestHex(
      "aac/fundraise-provekit/public-inputs/1",
      publicInputs,
    )),
    packet_public_inputs_commitment: hex32(digestHex(
      "aac/fundraise/public-inputs/1",
      packet.public_inputs ?? null,
    )),
    prover_toml_digest: hex32(digestTextHex(
      "aac/fundraise-demo-runner/prover-toml/1",
      proverToml,
    )),
    mapping: {
      circuit: "world-app/provekit-vnet cand-0095 ABI",
      atom_count: PROVEKIT_VNET_N_ATOMS,
      basis_width: PROVEKIT_VNET_N_BASIS,
      transition_rows_per_atom: PROVEKIT_VNET_N_TRANSITION_ROWS,
      public_inputs_order: Object.keys(publicInputs),
      fail_closed:
        "The runner refuses packets that do not exactly match the circuit's fixed atom count, basis, profile, account domain, transition-row width, or aggregate opening.",
    },
  };
  return {
    ...witness,
    witness_commitment: hex32(digestHex(
      "aac/fundraise-demo-runner/vnet-witness/1",
      {
        schema: witness.schema,
        public_inputs: witness.public_inputs,
        private_inputs: witness.private_inputs,
        packet_vnet_link_commitment: witness.packet_vnet_link_commitment,
      },
    )),
  };
}

export function buildProveKitVnetProverToml(packet) {
  return buildProveKitVnetWitnessFromPacket(packet).prover_toml;
}

export function buildPacketBoundPlaceholderProverToml(packet) {
  return [
    "# Prover.toml -- generated by fundraise-demo-runner for a non-VNET test circuit.",
    "# The production provekit-vnet package uses packet.vnet_link-derived witness fields.",
    `packet_commitment = "${hex32(digestHex("aac/fundraise-demo-runner/packet/1", packet ?? null))}"`,
    `packet_public_inputs_commitment = "${hex32(digestHex(
      "aac/fundraise/public-inputs/1",
      packet?.public_inputs ?? null,
    ))}"`,
    "",
  ].join("\n");
}

function assertProfileAndBasis(vnet) {
  if (vnet.profile_id !== PROVEKIT_VNET_PROFILE_ID) {
    fail("vnet_provekit_profile_mismatch", {
      expected: PROVEKIT_VNET_PROFILE_ID,
      actual: vnet.profile_id ?? null,
    });
  }
  if (!sameArray(vnet.basis_type_ids, PROVEKIT_VNET_BASIS)) {
    fail("vnet_provekit_basis_mismatch", {
      expected: PROVEKIT_VNET_BASIS,
      actual: Array.isArray(vnet.basis_type_ids) ? vnet.basis_type_ids : null,
    });
  }
  const basisCommitment = parseField(
    vnet.basis_commitment,
    "vnet_provekit_basis_commitment_missing",
    "vnet.basis_commitment",
  );
  if (basisCommitment !== BASIS_COMMITMENT_FIELD) {
    fail("vnet_provekit_basis_commitment_mismatch", {
      expected: fieldString(BASIS_COMMITMENT_FIELD),
      actual: fieldString(basisCommitment),
    });
  }
}

function normalizeAtom(atom, index) {
  if (!atom || typeof atom !== "object") {
    fail("vnet_provekit_atom_missing", { index });
  }
  if (atom.profile_id !== PROVEKIT_VNET_PROFILE_ID) {
    fail("vnet_provekit_atom_profile_mismatch", {
      index,
      expected: PROVEKIT_VNET_PROFILE_ID,
      actual: atom.profile_id ?? null,
    });
  }
  if (!sameArray(atom.basis_type_ids, PROVEKIT_VNET_BASIS)) {
    fail("vnet_provekit_atom_basis_mismatch", { index });
  }
  const atomBasis = parseField(
    atom.basis_commitment,
    "vnet_provekit_atom_basis_commitment_missing",
    `vnet.atoms[${index}].basis_commitment`,
  );
  if (atomBasis !== BASIS_COMMITMENT_FIELD) {
    fail("vnet_provekit_atom_basis_commitment_mismatch", { index });
  }

  const transition = normalizeTransitionWitness(atom, index);
  const debit = normalizeVector(atom.debit, `vnet.atoms[${index}].debit`);
  const credit = normalizeVector(atom.credit, `vnet.atoms[${index}].credit`);
  const transitionDebit = sumRows(transition.transition_debits);
  const transitionCredit = sumRows(transition.transition_credits);
  if (!sameBigIntArray(debit, transitionDebit)) {
    fail("vnet_provekit_atom_debit_mismatch", { index });
  }
  if (!sameBigIntArray(credit, transitionCredit)) {
    fail("vnet_provekit_atom_credit_mismatch", { index });
  }

  const rDebit = parseField(atom.debit_blinding, "vnet_provekit_debit_blinding_missing", `vnet.atoms[${index}].debit_blinding`);
  const rCredit = parseField(atom.credit_blinding, "vnet_provekit_credit_blinding_missing", `vnet.atoms[${index}].credit_blinding`);
  const debitCommitment = commit(debit, rDebit);
  const creditCommitment = commit(credit, rCredit);
  if (atom.debit_commitment) {
    assertSamePoint(
      debitCommitment,
      normalizePoint(atom.debit_commitment, `vnet.atoms[${index}].debit_commitment`),
      "vnet_provekit_debit_commitment_mismatch",
      { index },
    );
  }
  if (atom.credit_commitment) {
    assertSamePoint(
      creditCommitment,
      normalizePoint(atom.credit_commitment, `vnet.atoms[${index}].credit_commitment`),
      "vnet_provekit_credit_commitment_mismatch",
      { index },
    );
  }

  return {
    transition_ref: parseField(
      atom.transition_ref,
      "vnet_provekit_transition_ref_mismatch",
      `vnet.atoms[${index}].transition_ref`,
    ),
    journal_commitment: parseField(
      atom.journal_commitment,
      "vnet_provekit_journal_commitment_mismatch",
      `vnet.atoms[${index}].journal_commitment`,
    ),
    debit,
    credit,
    r_debit: rDebit,
    r_credit: rCredit,
    debit_commitment: debitCommitment,
    credit_commitment: creditCommitment,
    ...transition,
  };
}

function normalizeTransitionWitness(atom, index) {
  const link = atom.transition_link && typeof atom.transition_link === "object"
    ? atom.transition_link
    : {};
  const accounts = atom.transition_accounts ?? link.transition_accounts ?? link.accounts;
  const debits = atom.transition_debits ?? link.transition_debits ?? link.debits;
  const credits = atom.transition_credits ?? link.transition_credits ?? link.credits;
  if (!Array.isArray(accounts) || !Array.isArray(debits) || !Array.isArray(credits)) {
    fail("vnet_provekit_transition_witness_missing", { index });
  }
  if (accounts.length !== PROVEKIT_VNET_N_TRANSITION_ROWS) {
    fail("vnet_provekit_transition_row_count_mismatch", { index });
  }
  return {
    transition_accounts: accounts.map((value, row) => {
      const account = parseUnsigned(value, `vnet.atoms[${index}].transition_accounts[${row}]`);
      if (account >= BigInt(PROVEKIT_VNET_N_ACCT)) {
        fail("vnet_provekit_transition_account_mismatch", { index, row });
      }
      return account;
    }),
    transition_debits: normalizeRows(debits, `vnet.atoms[${index}].transition_debits`),
    transition_credits: normalizeRows(credits, `vnet.atoms[${index}].transition_credits`),
  };
}

function normalizeContextCommitment(vnet) {
  const value = vnet.context_commitment ?? vnet.circuit_context_commitment ?? SAMPLE_CONTEXT_COMMITMENT;
  const field = parseField(value, "vnet_provekit_context_commitment_mismatch", "vnet.context_commitment");
  if (field !== SAMPLE_CONTEXT_COMMITMENT) {
    fail("vnet_provekit_context_commitment_mismatch", {
      expected: fieldString(SAMPLE_CONTEXT_COMMITMENT),
      actual: fieldString(field),
    });
  }
  return field;
}

function aggregateOpening(atoms) {
  return msm([
    atoms[0].debit_commitment,
    atoms[1].debit_commitment,
    neg(atoms[0].credit_commitment),
    neg(atoms[1].credit_commitment),
  ], [1n, 1n, 1n, 1n]);
}

function assertZeroNet(atoms) {
  for (let j = 0; j < PROVEKIT_VNET_N_BASIS; j += 1) {
    let net = 0n;
    for (const atom of atoms) {
      net += atom.debit[j] - atom.credit[j];
    }
    if (net !== 0n) {
      fail("vnet_provekit_false_net", { basis_index: j, net: fieldString(net) });
    }
  }
}

function normalizeRows(rows, path) {
  if (!Array.isArray(rows) || rows.length !== PROVEKIT_VNET_N_TRANSITION_ROWS) {
    fail("vnet_provekit_transition_row_count_mismatch", { path });
  }
  return rows.map((row, index) => normalizeVector(row, `${path}[${index}]`));
}

function normalizeVector(vector, path) {
  if (!Array.isArray(vector) || vector.length !== PROVEKIT_VNET_N_BASIS) {
    fail("vnet_provekit_basis_width_mismatch", {
      path,
      expected: PROVEKIT_VNET_N_BASIS,
      actual: Array.isArray(vector) ? vector.length : null,
    });
  }
  return vector.map((value, index) => {
    const n = parseUnsigned(value, `${path}[${index}]`);
    if (n > PROVEKIT_VNET_MAX_COORD) {
      fail("vnet_provekit_coordinate_bound_mismatch", { path, index });
    }
    return n;
  });
}

function sumRows(rows) {
  const out = Array(PROVEKIT_VNET_N_BASIS).fill(0n);
  for (const row of rows) {
    for (let i = 0; i < row.length; i += 1) {
      out[i] += row[i];
    }
  }
  return out;
}

function renderProveKitVnetProverToml(publicInputs, privateInputs) {
  const values = { ...privateInputs, ...publicInputs };
  const lines = [
    "# Prover.toml -- generated from packet.vnet_link by fundraise-demo-runner.",
    "# Static example-witness copying is intentionally not used.",
    "",
  ];
  for (const [key, value] of Object.entries(values)) {
    lines.push(`${key} = ${tomlValue(value)}`);
  }
  lines.push("");
  return lines.join("\n");
}

function tomlValue(value) {
  if (Array.isArray(value)) {
    return `[${value.map(tomlValue).join(", ")}]`;
  }
  return `"${String(value).replaceAll("\\", "\\\\").replaceAll("\"", "\\\"")}"`;
}

function parseField(value, reason, path) {
  const out = parseUnsigned(value, path);
  if (out >= FIELD_MODULUS) {
    fail(reason, { path, actual: fieldString(out), modulus: fieldString(FIELD_MODULUS) });
  }
  return out;
}

function parseUnsigned(value, path) {
  try {
    if (typeof value === "bigint" && value >= 0n) return value;
    if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
      return BigInt(value);
    }
    if (typeof value === "string") {
      const s = value.trim();
      if (/^0x[0-9a-fA-F]+$/.test(s)) return BigInt(s);
      if (/^[0-9]+$/.test(s)) return BigInt(s);
      if (/^[0-9a-fA-F]+$/.test(s) && /[a-fA-F]/.test(s)) return BigInt(`0x${s}`);
    }
  } catch {
    // fall through to typed refusal below
  }
  fail("vnet_provekit_field_encoding_mismatch", { path, value });
}

function normalizePoint(value, path) {
  if (!value || typeof value !== "object") {
    fail("vnet_provekit_point_missing", { path });
  }
  const point = [
    parseField(value.x, "vnet_provekit_point_encoding_mismatch", `${path}.x`),
    parseField(value.y, "vnet_provekit_point_encoding_mismatch", `${path}.y`),
  ];
  assertOnCurve(point, path);
  return point;
}

function assertSamePoint(a, b, reason, detail = {}) {
  if (!a || !b || a[0] !== b[0] || a[1] !== b[1]) {
    fail(reason, {
      ...detail,
      expected: b ? b.map(fieldString) : null,
      actual: a ? a.map(fieldString) : null,
    });
  }
}

function assertOnCurve(point, path) {
  const [x, y] = point;
  if (mod(y * y - x * x * x - GRUMPKIN_B) !== 0n) {
    fail("vnet_provekit_point_not_on_curve", { path });
  }
}

function commit(vector, blinding) {
  return msm([G[0], G[1], G[2], H], [vector[0], vector[1], vector[2], blinding]);
}

function msm(points, scalars) {
  let out = null;
  for (let i = 0; i < points.length; i += 1) {
    out = add(out, mul(scalars[i], points[i]));
  }
  if (out === null) fail("vnet_provekit_point_at_infinity");
  return out;
}

function add(a, b) {
  if (a === null) return b;
  if (b === null) return a;
  const [x1, y1] = a;
  const [x2, y2] = b;
  if (x1 === x2 && mod(y1 + y2) === 0n) return null;
  const lambda = x1 === x2 && y1 === y2
    ? mod(3n * x1 * x1 * inv(2n * y1))
    : mod((y2 - y1) * inv(x2 - x1));
  const x3 = mod(lambda * lambda - x1 - x2);
  const y3 = mod(lambda * (x1 - x3) - y1);
  return [x3, y3];
}

function neg(point) {
  return point === null ? null : [point[0], mod(-point[1])];
}

function mul(k, point) {
  let scalar = mod(k);
  let out = null;
  let cur = point;
  while (scalar > 0n) {
    if (scalar & 1n) out = add(out, cur);
    cur = add(cur, cur);
    scalar >>= 1n;
  }
  return out;
}

function inv(value) {
  return powMod(value, FIELD_MODULUS - 2n);
}

function powMod(base, exp) {
  let b = mod(base);
  let e = exp;
  let out = 1n;
  while (e > 0n) {
    if (e & 1n) out = (out * b) % FIELD_MODULUS;
    b = (b * b) % FIELD_MODULUS;
    e >>= 1n;
  }
  return out;
}

function mod(value) {
  const out = value % FIELD_MODULUS;
  return out >= 0n ? out : out + FIELD_MODULUS;
}

function digestTextHex(label, text) {
  return createHash("sha256").update(`${label}\n${text}`).digest("hex");
}

function sameArray(a, b) {
  return Array.isArray(a) && a.length === b.length && a.every((value, index) => value === b[index]);
}

function sameBigIntArray(a, b) {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function hex32(value) {
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new ProveKitVnetPacketBindingError("bad_hex32", "bad_hex32", { value });
  }
  return `0x${raw.toLowerCase()}`;
}

function fieldString(value) {
  return value.toString(10);
}

function fail(reason, detail = {}) {
  throw new ProveKitVnetPacketBindingError(reason, reason, detail);
}
