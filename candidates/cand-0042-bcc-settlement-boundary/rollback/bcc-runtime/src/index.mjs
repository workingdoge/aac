import { createHash } from "node:crypto";

export const CERTIFICATE_SCHEMA = "aac.bcc.certificate.v1";
export const VECTOR_SCHEMA = "aac.bcc-demo.conformance.v1";
export const MOCK_COMMITMENT_SCHEME = "mock-vector-commitment/1";
export const MOCK_SIGNATURE_SCHEME = "mock-signature/1";
export const MOCK_DH_SCHEME = "mock-dh-edge/1";

export class BccVerificationError extends Error {
  constructor(reason, message = reason) {
    super(message);
    this.name = "BccVerificationError";
    this.reason = reason;
  }
}

export function canonical(value) {
  return JSON.stringify(sortCanonical(value));
}

export function digestHex(label, ...parts) {
  return createHash("sha256").update(canonical([label, ...parts])).digest("hex");
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

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

export function createBilateralEvent(input = {}) {
  return {
    event_id: "goods-for-cash-001",
    description: "Buyer receives 3 goods units and seller receives 10 USD units.",
    basis_type_ids: ["GOOD:demo-widget:unit", "USD:arc-testnet:atomic"],
    state_refs: {
      buyer_row: "buyer-row/transition/7",
      seller_row: "seller-row/transition/12",
    },
    ...input,
  };
}

export function mockCommitVector({ basis_type_ids, vector, blinding }) {
  return {
    scheme: MOCK_COMMITMENT_SCHEME,
    value: digestHex("aac/bcc/mock-vector-commitment/1", basis_type_ids, vector, blinding),
  };
}

export function createRecord(input) {
  const basis = input.basis_type_ids;
  if (!Array.isArray(basis) || basis.length === 0) fail("basis_missing");
  if (input.debit.length !== basis.length || input.credit.length !== basis.length) fail("vector_width_mismatch");
  const debit_blinding = input.debit_blinding ?? `${input.party_id}:debit`;
  const credit_blinding = input.credit_blinding ?? `${input.party_id}:credit`;
  return {
    party_id: input.party_id,
    role: input.role,
    transition_ref: input.transition_ref,
    journal_commitment: input.journal_commitment,
    basis_type_ids: [...basis],
    debit: [...input.debit],
    credit: [...input.credit],
    debit_blinding,
    credit_blinding,
    debit_commitment: input.debit_commitment ?? mockCommitVector({ basis_type_ids: basis, vector: input.debit, blinding: debit_blinding }),
    credit_commitment: input.credit_commitment ?? mockCommitVector({ basis_type_ids: basis, vector: input.credit, blinding: credit_blinding }),
  };
}

export function createDhEdge({ party_a, party_b, public_a = "buyer-ephemeral-key", public_b = "seller-ephemeral-key" } = {}) {
  const participants = {
    [party_a ?? "buyer.example"]: public_a,
    [party_b ?? "seller.example"]: public_b,
  };
  return {
    scheme: MOCK_DH_SCHEME,
    ephemeral_public_keys: participants,
    edge_tag: digestHex("aac/bcc/mock-dh-edge/1", participants),
  };
}

export function transcriptPayload(cert) {
  return {
    schema: cert.schema,
    event: cert.event,
    basis_type_ids: cert.basis_type_ids,
    records: cert.records.map((r) => ({
      party_id: r.party_id,
      role: r.role,
      transition_ref: r.transition_ref,
      journal_commitment: r.journal_commitment,
      basis_type_ids: r.basis_type_ids,
      debit: r.debit,
      credit: r.credit,
      debit_commitment: r.debit_commitment,
      credit_commitment: r.credit_commitment,
    })),
    vnet_certificate: cert.vnet_certificate,
    dh_edge: cert.dh_edge ?? null,
    finality: cert.finality
      ? {
          scheme: cert.finality.scheme,
          log_ref: cert.finality.log_ref,
          nullifier: cert.finality.nullifier,
        }
      : null,
  };
}

export function transcriptHash(cert) {
  return digestHex("aac/bcc/transcript/1", transcriptPayload(cert));
}

export function mockSignTranscript({ party_id, public_key, transcript_hash }) {
  return {
    party_id,
    public_key,
    scheme: MOCK_SIGNATURE_SCHEME,
    signature: digestHex("aac/bcc/mock-signature/1", party_id, public_key, transcript_hash),
  };
}

export function buildVnetCertificate(records) {
  const [debit, credit] = amountTotals(records);
  return {
    scheme: "bcc-vnet-transparent/1",
    commitment_scheme: MOCK_COMMITMENT_SCHEME,
    aggregate_debit: debit,
    aggregate_credit: credit,
    zero_opening: vectorsEqual(debit, credit),
    atom_count: records.length,
  };
}

export function buildFinality({ transcript_hash, log_ref = "demo-log", nullifier } = {}) {
  const n = nullifier ?? digestHex("aac/bcc/nullifier/1", transcript_hash);
  return {
    scheme: "bcc-finality-tag/1",
    log_ref,
    nullifier: n,
    finality_tag: digestHex("aac/bcc/finality/1", log_ref, n, transcript_hash),
  };
}

export function buildBilateralCertificate({ event, records, dh_edge, signer_public_keys, finality_context } = {}) {
  const normalizedEvent = createBilateralEvent(event);
  const basis = normalizedEvent.basis_type_ids;
  const normalizedRecords = records.map((record) => createRecord({ ...record, basis_type_ids: record.basis_type_ids ?? basis }));
  const log_ref = finality_context?.log_ref ?? "demo-log";
  const nullifier = finality_context?.nullifier ?? digestHex("aac/bcc/nullifier/1", normalizedEvent, normalizedRecords);
  const partial = {
    schema: CERTIFICATE_SCHEMA,
    event: normalizedEvent,
    basis_type_ids: [...basis],
    records: normalizedRecords,
    vnet_certificate: buildVnetCertificate(normalizedRecords),
    dh_edge: dh_edge ?? createDhEdge({
      party_a: normalizedRecords[0]?.party_id,
      party_b: normalizedRecords[1]?.party_id,
    }),
    finality: { scheme: "bcc-finality-tag/1", log_ref, nullifier, finality_tag: "" },
    transcript_hash: "",
    signatures: [],
  };
  partial.transcript_hash = transcriptHash(partial);
  partial.finality = buildFinality({ log_ref, nullifier, transcript_hash: partial.transcript_hash });
  const signerKeys = signer_public_keys ?? Object.fromEntries(normalizedRecords.map((r) => [r.party_id, `${r.party_id}:pub`]));
  partial.signatures = normalizedRecords.map((r) =>
    mockSignTranscript({
      party_id: r.party_id,
      public_key: signerKeys[r.party_id],
      transcript_hash: partial.transcript_hash,
    }),
  );
  return partial;
}

export function verifyBilateralCertificate(cert, opts = {}) {
  try {
    checkCertificate(cert, opts);
    return { accepted: true, reason: "accepted", authorization: authorizeFinality(cert) };
  } catch (err) {
    if (err instanceof BccVerificationError) return { accepted: false, reason: err.reason };
    throw err;
  }
}

export function authorizeFinality(cert) {
  return {
    schema: "aac.bcc-runtime.finality-authorization.v1",
    transcript_hash: cert.transcript_hash,
    finality_tag: cert.finality.finality_tag,
    nullifier: cert.finality.nullifier,
    parties: cert.records.map((r) => r.party_id),
    authorization_digest: digestHex("aac/bcc/finality-authorization/1", {
      transcript_hash: cert.transcript_hash,
      finality_tag: cert.finality.finality_tag,
      nullifier: cert.finality.nullifier,
    }),
  };
}

function checkCertificate(cert, opts) {
  if (cert.schema !== CERTIFICATE_SCHEMA) fail("schema_mismatch");
  if (!Array.isArray(cert.records) || cert.records.length !== 2) fail("two_party_shape");
  const parties = new Set(cert.records.map((r) => r.party_id));
  if (parties.size !== 2) fail("duplicate_party");

  for (const record of cert.records) {
    if (!vectorsEqual(record.basis_type_ids, cert.basis_type_ids)) fail("basis_mismatch");
    if (record.debit.length !== cert.basis_type_ids.length || record.credit.length !== cert.basis_type_ids.length) {
      fail("vector_width_mismatch");
    }
    if (!record.debit.every(nonNegativeInt) || !record.credit.every(nonNegativeInt)) fail("bad_amount");
    if (record.debit_commitment.value !== mockCommitVector({
      basis_type_ids: record.basis_type_ids,
      vector: record.debit,
      blinding: record.debit_blinding,
    }).value) fail("debit_commitment_mismatch");
    if (record.credit_commitment.value !== mockCommitVector({
      basis_type_ids: record.basis_type_ids,
      vector: record.credit,
      blinding: record.credit_blinding,
    }).value) fail("credit_commitment_mismatch");
  }

  const [debit, credit] = amountTotals(cert.records);
  if (!vectorsEqual(debit, credit)) fail("vnet_zero_opening");
  if (!cert.vnet_certificate?.zero_opening) fail("vnet_zero_opening");
  if (!vectorsEqual(cert.vnet_certificate.aggregate_debit, debit)) fail("vnet_debit_mismatch");
  if (!vectorsEqual(cert.vnet_certificate.aggregate_credit, credit)) fail("vnet_credit_mismatch");

  if (cert.dh_edge) {
    const want = digestHex("aac/bcc/mock-dh-edge/1", cert.dh_edge.ephemeral_public_keys);
    if (cert.dh_edge.edge_tag !== want) fail("dh_edge_tag_mismatch");
  }

  if (cert.transcript_hash !== transcriptHash(cert)) fail("transcript_hash_mismatch");
  const sigs = new Map(cert.signatures.map((s) => [s.party_id, s]));
  for (const record of cert.records) {
    const sig = sigs.get(record.party_id);
    if (!sig) fail("signature_missing");
    const want = mockSignTranscript({
      party_id: record.party_id,
      public_key: sig.public_key,
      transcript_hash: cert.transcript_hash,
    });
    if (sig.signature !== want.signature) fail("signature_mismatch");
  }

  if (!cert.finality?.finality_tag || !cert.finality?.nullifier) fail("finality_missing");
  const wantFinality = buildFinality({
    transcript_hash: cert.transcript_hash,
    log_ref: cert.finality.log_ref,
    nullifier: cert.finality.nullifier,
  });
  if (cert.finality.finality_tag !== wantFinality.finality_tag) fail("finality_tag_mismatch");
  const seen = opts.seenFinalityTags ?? new Set(opts.seen_finality_tags ?? []);
  if (seen.has(cert.finality.finality_tag)) fail("finality_replay");
}

export function amountTotals(records) {
  const width = records[0]?.debit.length ?? 0;
  const debit = Array(width).fill(0);
  const credit = Array(width).fill(0);
  for (const record of records) {
    for (let i = 0; i < width; i += 1) {
      debit[i] += record.debit[i];
      credit[i] += record.credit[i];
    }
  }
  return [debit, credit];
}

export function demoCertificate() {
  const event = createBilateralEvent();
  const basis = event.basis_type_ids;
  return buildBilateralCertificate({
    event,
    records: [
      {
        party_id: "buyer.example",
        role: "buyer",
        transition_ref: "buyer-row/transition/7",
        journal_commitment: "17171717171717171717171717171717",
        basis_type_ids: basis,
        debit: [3, 0],
        credit: [0, 10],
      },
      {
        party_id: "seller.example",
        role: "seller",
        transition_ref: "seller-row/transition/12",
        journal_commitment: "29292929292929292929292929292929",
        basis_type_ids: basis,
        debit: [0, 10],
        credit: [3, 0],
      },
    ],
  });
}

export function demoVectors() {
  const good = demoCertificate();
  const sigBad = clone(good);
  sigBad.signatures[0].signature = "bad-signature";
  const vnetBad = clone(good);
  vnetBad.records[0].credit[1] += 1;
  vnetBad.records[0].credit_commitment = mockCommitVector({
    basis_type_ids: vnetBad.records[0].basis_type_ids,
    vector: vnetBad.records[0].credit,
    blinding: vnetBad.records[0].credit_blinding,
  });
  vnetBad.vnet_certificate = buildVnetCertificate(vnetBad.records);
  vnetBad.transcript_hash = transcriptHash(vnetBad);
  vnetBad.signatures = vnetBad.records.map((r) =>
    mockSignTranscript({ party_id: r.party_id, public_key: `${r.party_id}:pub`, transcript_hash: vnetBad.transcript_hash }),
  );
  const transcriptBad = clone(good);
  transcriptBad.event.description = "tampered after signing";
  const replayBad = clone(good);
  return {
    schema: VECTOR_SCHEMA,
    vectors: [
      {
        id: "bcc-good-goods-for-cash",
        description: "buyer and seller sign opposite goods-for-cash records; VNET-style totals cancel",
        certificate: good,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: true, reason: "accepted" },
      },
      {
        id: "bcc-signature-mismatch-reject",
        description: "one party signature no longer matches the transcript hash",
        certificate: sigBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "signature_mismatch" },
      },
      {
        id: "bcc-vnet-false-net-reject",
        description: "records are signed but no longer cancel per basis dimension",
        certificate: vnetBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "vnet_zero_opening" },
      },
      {
        id: "bcc-transcript-mismatch-reject",
        description: "event text changes after signatures and transcript hash are fixed",
        certificate: transcriptBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "transcript_hash_mismatch" },
      },
      {
        id: "bcc-finality-replay-reject",
        description: "otherwise valid certificate repeats an already accepted finality tag",
        certificate: replayBad,
        verifier_context: { seen_finality_tags: [replayBad.finality.finality_tag] },
        expect: { accepted: false, reason: "finality_replay" },
      },
    ],
  };
}

function nonNegativeInt(n) {
  return Number.isSafeInteger(n) && n >= 0;
}

function vectorsEqual(a, b) {
  return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => x === b[i]);
}

function fail(reason) {
  throw new BccVerificationError(reason);
}
