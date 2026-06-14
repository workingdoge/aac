import { createHash } from "node:crypto";

export const CERTIFICATE_SCHEMA = "aac.bcc.certificate.v1";
export const WITNESS_SCHEMA = "aac.bcc.private-witness.v1";
export const PACKET_SCHEMA = "aac.bcc.packet.v1";
export const VECTOR_SCHEMA = "aac.bcc-demo.conformance.v1";
export const MOCK_RECORD_COMMITMENT_SCHEME = "mock-record-commitment/1";
export const MOCK_CANCELLATION_SCHEME = "mock-cancellation-opening/1";
export const FIXTURE_VNET_CANCELLATION_SCHEME = "fixture-vnet-cancellation/1";
export const CANCELLATION_PAYLOAD_SCHEMA = "aac.bcc.cancellation-payload.v1";
export const MOCK_SIGNATURE_SCHEME = "mock-signature/1";
export const EIP712_SIGNATURE_SCHEME = "eip712-adapter/1";
export const SIGNATURE_TYPED_DATA_SCHEMA = "aac.bcc.signature-typed-data.v1";
export const MOCK_AUTHENTICATED_ECDH_SCHEME = "mock-authenticated-ecdh/1";

// Compatibility aliases for callers of the cand-0041 runtime.
export const MOCK_COMMITMENT_SCHEME = MOCK_RECORD_COMMITMENT_SCHEME;
export const MOCK_DH_SCHEME = MOCK_AUTHENTICATED_ECDH_SCHEME;

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
    bridge_context: {
      registry: "demo-private-state-registry",
      settlement_contract: "demo-bridge-vault",
      asset: "USDC:arc-testnet",
    },
    ...input,
  };
}

export function signedVector(record) {
  return record.debit.map((amount, i) => amount - record.credit[i]);
}

export function mockCommitRecord({ basis_type_ids, debit, credit, blinding }) {
  return {
    scheme: MOCK_RECORD_COMMITMENT_SCHEME,
    value: digestHex("aac/bcc/mock-record-commitment/1", basis_type_ids, signedVector({ debit, credit }), blinding),
  };
}

export function mockCommitVector({ basis_type_ids, vector, blinding }) {
  return {
    scheme: MOCK_RECORD_COMMITMENT_SCHEME,
    value: digestHex("aac/bcc/mock-vector-commitment/compat", basis_type_ids, vector, blinding),
  };
}

export function createRecord(input) {
  const basis = input.basis_type_ids;
  if (!Array.isArray(basis) || basis.length === 0) fail("basis_missing");
  if (!Array.isArray(input.debit) || !Array.isArray(input.credit)) fail("vector_missing");
  if (input.debit.length !== basis.length || input.credit.length !== basis.length) fail("vector_width_mismatch");
  if (!input.debit.every(nonNegativeInt) || !input.credit.every(nonNegativeInt)) fail("bad_amount");
  const record_blinding = input.record_blinding ?? input.blinding ?? `${input.party_id}:record`;
  const record = {
    party_id: input.party_id,
    role: input.role,
    transition_ref: input.transition_ref,
    journal_commitment: input.journal_commitment,
    basis_type_ids: [...basis],
    debit: [...input.debit],
    credit: [...input.credit],
    record_blinding,
  };
  return {
    ...record,
    record_commitment: input.record_commitment ?? mockCommitRecord({
      basis_type_ids: basis,
      debit: input.debit,
      credit: input.credit,
      blinding: record_blinding,
    }),
  };
}

export function publicRecord(record) {
  return {
    party_id: record.party_id,
    role: record.role,
    transition_ref: record.transition_ref,
    journal_commitment: record.journal_commitment,
    basis_type_ids: [...record.basis_type_ids],
    record_commitment: clone(record.record_commitment),
  };
}

export function createAuthenticatedDh({
  party_a,
  party_b,
  public_a = "buyer-ephemeral-x25519",
  public_b = "seller-ephemeral-x25519",
} = {}) {
  const participants = {
    [party_a ?? "buyer.example"]: public_a,
    [party_b ?? "seller.example"]: public_b,
  };
  return {
    scheme: MOCK_AUTHENTICATED_ECDH_SCHEME,
    ephemeral_public_keys: participants,
    kdf: "hkdf-sha256",
    transcript_binding: "ephemeral keys are signed inside transcript_hash",
    public_edge_tag: digestHex("aac/bcc/mock-authenticated-ecdh/1", participants),
  };
}

export function createDhEdge(input = {}) {
  return createAuthenticatedDh(input);
}

export function buildPrivateWitness(records) {
  return {
    schema: WITNESS_SCHEMA,
    records: records.map((record) => ({
      party_id: record.party_id,
      role: record.role,
      basis_type_ids: [...record.basis_type_ids],
      debit: [...record.debit],
      credit: [...record.credit],
      record_blinding: record.record_blinding,
    })),
    aggregate_opening: aggregateOpening(records),
  };
}

export function buildCancellationOpening(records, publicRecords = records.map(publicRecord)) {
  const net = amountNet(records);
  const zero_opening = net.every((amount) => amount === 0);
  const aggregate_opening = aggregateOpening(records);
  return {
    scheme: MOCK_CANCELLATION_SCHEME,
    commitment_scheme: MOCK_RECORD_COMMITMENT_SCHEME,
    aggregate_opening,
    zero_opening,
    proof_digest: cancellationProofDigest(publicRecords, aggregate_opening, zero_opening),
    record_count: publicRecords.length,
  };
}

export function buildVnetCertificate(records) {
  return buildCancellationOpening(records);
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
      record_commitment: r.record_commitment,
    })),
    cancellation_opening: cert.cancellation_opening,
    authenticated_dh: cert.authenticated_dh ?? null,
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

export function bccSignatureTypedData(cert, signature, domain = {}) {
  return {
    schema: SIGNATURE_TYPED_DATA_SCHEMA,
    kind: "eip712-compatible",
    domain: {
      name: domain.name ?? "AAC Bilateral Cancellation Certificate",
      version: domain.version ?? "1",
      chainId: domain.chainId ?? domain.chain_id ?? "",
      verifyingContract: domain.verifyingContract ?? domain.verifying_contract ?? "",
      salt: domain.salt ?? "",
    },
    primaryType: "BccCertificateSignature",
    types: {
      BccCertificateSignature: [
        { name: "certificateSchema", type: "string" },
        { name: "transcriptHash", type: "bytes32" },
        { name: "partyId", type: "string" },
        { name: "publicKey", type: "string" },
        { name: "signatureScheme", type: "string" },
        { name: "finalityTag", type: "bytes32" },
        { name: "nullifier", type: "bytes32" },
        { name: "logRef", type: "string" },
      ],
    },
    message: {
      certificateSchema: cert.schema,
      transcriptHash: `0x${cert.transcript_hash}`,
      partyId: signature.party_id,
      publicKey: signature.public_key,
      signatureScheme: signature.scheme,
      finalityTag: `0x${cert.finality.finality_tag}`,
      nullifier: `0x${cert.finality.nullifier}`,
      logRef: cert.finality.log_ref,
    },
  };
}

export function fixtureSignTypedData({ certificate, party_id, public_key, domain } = {}) {
  const signature = {
    party_id,
    public_key,
    scheme: EIP712_SIGNATURE_SCHEME,
    signature: "",
  };
  const typedData = bccSignatureTypedData(certificate, signature, domain);
  return {
    ...signature,
    signature: digestHex("aac/bcc/fixture-eip712-signature/1", typedData.message, typedData.domain),
  };
}

export function fixtureVerifyTypedDataSignature({ signature, typed_data }) {
  const want = digestHex("aac/bcc/fixture-eip712-signature/1", typed_data.message, typed_data.domain);
  return signature.signature === want;
}

export function bccCancellationPayload(cert) {
  const opening = clone(cert.cancellation_opening);
  delete opening.proof_digest;
  return {
    schema: CANCELLATION_PAYLOAD_SCHEMA,
    certificateSchema: cert.schema,
    basis_type_ids: [...cert.basis_type_ids],
    records: cert.records.map((r) => ({
      party_id: r.party_id,
      role: r.role,
      transition_ref: r.transition_ref,
      journal_commitment: r.journal_commitment,
      basis_type_ids: [...r.basis_type_ids],
      record_commitment: clone(r.record_commitment),
    })),
    cancellation_opening: opening,
  };
}

export function fixtureProveCancellation(cert) {
  const opening = {
    scheme: FIXTURE_VNET_CANCELLATION_SCHEME,
    commitment_scheme: "vnet-bn254-g1/1",
    aggregate_opening: cert.cancellation_opening.aggregate_opening,
    zero_opening: true,
    proof_digest: "",
    record_count: cert.records.length,
  };
  const partial = { ...cert, cancellation_opening: opening };
  return {
    ...opening,
    proof_digest: digestHex("aac/bcc/fixture-vnet-cancellation/1", bccCancellationPayload(partial)),
  };
}

export function fixtureVerifyCancellation({ cancellation_opening, payload }) {
  const want = digestHex("aac/bcc/fixture-vnet-cancellation/1", payload);
  return cancellation_opening.proof_digest === want;
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

export function buildBilateralPacket({ event, records, authenticated_dh, dh_edge, signer_public_keys, finality_context } = {}) {
  const normalizedEvent = createBilateralEvent(event);
  const basis = normalizedEvent.basis_type_ids;
  const privateRecords = records.map((record) => createRecord({ ...record, basis_type_ids: record.basis_type_ids ?? basis }));
  const publicRecords = privateRecords.map(publicRecord);
  const cancellation_opening = buildCancellationOpening(privateRecords, publicRecords);
  const log_ref = finality_context?.log_ref ?? "demo-log";
  const nullifier = finality_context?.nullifier ?? digestHex("aac/bcc/nullifier/1", normalizedEvent, publicRecords, cancellation_opening);
  const partial = {
    schema: CERTIFICATE_SCHEMA,
    event: normalizedEvent,
    basis_type_ids: [...basis],
    records: publicRecords,
    cancellation_opening,
    authenticated_dh: authenticated_dh ?? dh_edge ?? createAuthenticatedDh({
      party_a: publicRecords[0]?.party_id,
      party_b: publicRecords[1]?.party_id,
    }),
    finality: { scheme: "bcc-finality-tag/1", log_ref, nullifier, finality_tag: "" },
    transcript_hash: "",
    signatures: [],
  };
  partial.transcript_hash = transcriptHash(partial);
  partial.finality = buildFinality({ log_ref, nullifier, transcript_hash: partial.transcript_hash });
  const signerKeys = signer_public_keys ?? Object.fromEntries(publicRecords.map((r) => [r.party_id, `${r.party_id}:pub`]));
  partial.signatures = publicRecords.map((r) =>
    mockSignTranscript({
      party_id: r.party_id,
      public_key: signerKeys[r.party_id],
      transcript_hash: partial.transcript_hash,
    }),
  );
  return {
    schema: PACKET_SCHEMA,
    certificate: partial,
    private_witness: buildPrivateWitness(privateRecords),
  };
}

export function buildBilateralCertificate(input = {}) {
  return buildBilateralPacket(input).certificate;
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

export function verifyBilateralPacket(packet, opts = {}) {
  try {
    if (packet.schema !== PACKET_SCHEMA) fail("packet_schema_mismatch");
    checkCertificate(packet.certificate, opts);
    checkPrivateWitness(packet.certificate, packet.private_witness);
    return { accepted: true, reason: "accepted", authorization: authorizeFinality(packet.certificate) };
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
    settlement_boundary: "agreement-certificate-only",
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
    if ("debit" in record || "credit" in record || "record_blinding" in record) fail("private_witness_leak");
    if (!record.record_commitment || record.record_commitment.scheme !== MOCK_RECORD_COMMITMENT_SCHEME) {
      fail("record_commitment_missing");
    }
  }

  checkCancellationOpening(cert, opts);
  checkAuthenticatedDh(cert);

  if (cert.transcript_hash !== transcriptHash(cert)) fail("transcript_hash_mismatch");
  const sigs = new Map(cert.signatures.map((s) => [s.party_id, s]));
  for (const record of cert.records) {
    const sig = sigs.get(record.party_id);
    if (!sig) fail("signature_missing");
    checkSignature(cert, record, sig, opts);
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

function checkSignature(cert, record, sig, opts) {
  if (sig.scheme === MOCK_SIGNATURE_SCHEME) {
    const want = mockSignTranscript({
      party_id: record.party_id,
      public_key: sig.public_key,
      transcript_hash: cert.transcript_hash,
    });
    if (sig.signature !== want.signature) fail("signature_mismatch");
    return;
  }

  const verifySignature = opts.verifySignature ?? opts.verify_signature;
  if (typeof verifySignature !== "function") fail("signature_verifier_missing");

  const typed_data = bccSignatureTypedData(cert, sig, opts.signatureDomain ?? opts.signature_domain ?? {});
  const result = verifySignature({
    certificate: cert,
    record,
    signature: sig,
    typed_data,
    transcript_hash: cert.transcript_hash,
  });
  if (result === true || result?.accepted === true) return;
  if (result && typeof result === "object" && typeof result.reason === "string") {
    fail(result.reason.startsWith("signature_") ? result.reason : `signature_${result.reason}`);
  }
  fail("signature_mismatch");
}

function checkCancellationOpening(cert, opts) {
  const opening = cert.cancellation_opening;
  if (opening?.scheme !== MOCK_CANCELLATION_SCHEME) {
    const verifyCancellation = opts.verifyCancellation ?? opts.verify_cancellation;
    if (typeof verifyCancellation !== "function") fail("cancellation_verifier_missing");
    const payload = bccCancellationPayload(cert);
    const result = verifyCancellation({
      certificate: cert,
      cancellation_opening: opening,
      payload,
    });
    if (result === true || result?.accepted === true) return;
    if (result && typeof result === "object" && typeof result.reason === "string") {
      fail(result.reason.startsWith("cancellation_") ? result.reason : `cancellation_${result.reason}`);
    }
    fail("cancellation_proof_mismatch");
  }
  if (!opening || opening.scheme !== MOCK_CANCELLATION_SCHEME) fail("cancellation_opening_missing");
  if (opening.commitment_scheme !== MOCK_RECORD_COMMITMENT_SCHEME) fail("cancellation_commitment_scheme_mismatch");
  if (opening.record_count !== cert.records.length) fail("cancellation_record_count_mismatch");
  const wantDigest = cancellationProofDigest(cert.records, opening.aggregate_opening, opening.zero_opening);
  if (opening.proof_digest !== wantDigest) fail("cancellation_opening_mismatch");
  if (opening.zero_opening !== true) fail("cancellation_zero_opening");
}

function checkAuthenticatedDh(cert) {
  const dh = cert.authenticated_dh;
  if (!dh) return;
  if (dh.scheme !== MOCK_AUTHENTICATED_ECDH_SCHEME) fail("authenticated_dh_scheme_mismatch");
  const expectedParties = cert.records.map((r) => r.party_id);
  const actualParties = Object.keys(dh.ephemeral_public_keys ?? {});
  if (!vectorsEqual([...actualParties].sort(), [...expectedParties].sort())) fail("authenticated_dh_party_mismatch");
  const want = digestHex("aac/bcc/mock-authenticated-ecdh/1", dh.ephemeral_public_keys);
  if (dh.public_edge_tag !== want) fail("authenticated_dh_mismatch");
}

function checkPrivateWitness(cert, witness) {
  if (witness?.schema !== WITNESS_SCHEMA) fail("witness_schema_mismatch");
  if (!Array.isArray(witness.records) || witness.records.length !== cert.records.length) fail("witness_record_mismatch");
  const byParty = new Map(witness.records.map((record) => [record.party_id, record]));
  const normalized = [];
  for (const publicRec of cert.records) {
    const privateRec = byParty.get(publicRec.party_id);
    if (!privateRec) fail("witness_record_mismatch");
    if (privateRec.role !== publicRec.role) fail("witness_record_mismatch");
    if (!vectorsEqual(privateRec.basis_type_ids, publicRec.basis_type_ids)) fail("basis_mismatch");
    if (!privateRec.debit.every(nonNegativeInt) || !privateRec.credit.every(nonNegativeInt)) fail("bad_amount");
    const record = createRecord({
      party_id: privateRec.party_id,
      role: privateRec.role,
      transition_ref: publicRec.transition_ref,
      journal_commitment: publicRec.journal_commitment,
      basis_type_ids: privateRec.basis_type_ids,
      debit: privateRec.debit,
      credit: privateRec.credit,
      record_blinding: privateRec.record_blinding,
    });
    if (record.record_commitment.value !== publicRec.record_commitment.value) fail("record_commitment_mismatch");
    normalized.push(record);
  }
  if (!amountNet(normalized).every((amount) => amount === 0)) fail("cancellation_witness_mismatch");
  if (aggregateOpening(normalized) !== witness.aggregate_opening) fail("aggregate_opening_mismatch");
  if (witness.aggregate_opening !== cert.cancellation_opening.aggregate_opening) fail("aggregate_opening_mismatch");
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

export function amountNet(records) {
  const width = records[0]?.debit.length ?? 0;
  const net = Array(width).fill(0);
  for (const record of records) {
    const signed = signedVector(record);
    for (let i = 0; i < width; i += 1) net[i] += signed[i];
  }
  return net;
}

export function demoPacket() {
  const event = createBilateralEvent();
  const basis = event.basis_type_ids;
  return buildBilateralPacket({
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

export function demoCertificate() {
  return demoPacket().certificate;
}

export function demoVectors() {
  const goodPacket = demoPacket();
  const good = goodPacket.certificate;
  const sigBad = clone(good);
  sigBad.signatures[0].signature = "bad-signature";
  const typedDataGood = clone(good);
  typedDataGood.signatures = typedDataGood.signatures.map((sig) =>
    fixtureSignTypedData({
      certificate: typedDataGood,
      party_id: sig.party_id,
      public_key: sig.public_key,
    }),
  );
  const typedDataNoVerifier = clone(typedDataGood);
  const typedDataBadSigner = clone(typedDataGood);
  typedDataBadSigner.signatures[0].public_key = "wrong-signer";
  const cancellationAdapterGood = withFixtureCancellationAdapter(good);
  const cancellationAdapterNoVerifier = clone(cancellationAdapterGood);
  const cancellationAdapterBadProof = clone(cancellationAdapterGood);
  cancellationAdapterBadProof.cancellation_opening.proof_digest = "bad-proof";

  const falseNetPacket = buildBilateralPacket({
    event: good.event,
    records: [
      {
        party_id: "buyer.example",
        role: "buyer",
        transition_ref: "buyer-row/transition/7",
        journal_commitment: "17171717171717171717171717171717",
        basis_type_ids: good.basis_type_ids,
        debit: [3, 0],
        credit: [0, 11],
      },
      {
        party_id: "seller.example",
        role: "seller",
        transition_ref: "seller-row/transition/12",
        journal_commitment: "29292929292929292929292929292929",
        basis_type_ids: good.basis_type_ids,
        debit: [0, 10],
        credit: [3, 0],
      },
    ],
  });

  const transcriptBad = clone(good);
  transcriptBad.event.description = "tampered after signing";

  const dhBad = clone(good);
  dhBad.authenticated_dh.public_edge_tag = "bad-edge-tag";

  const leakBad = clone(good);
  leakBad.records[0].debit = [3, 0];

  const replayBad = clone(good);
  return {
    schema: VECTOR_SCHEMA,
    vectors: [
      {
        id: "bcc-good-goods-for-cash",
        description: "public certificate carries only commitments, cancellation opening, authenticated ECDH material, signatures, and finality refs",
        certificate: good,
        private_witness: goodPacket.private_witness,
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
        id: "bcc-eip712-adapter-accept",
        description: "non-mock typed-data signatures verify through the supplied signature adapter",
        certificate: typedDataGood,
        verifier_context: { signature_adapter: "fixture-eip712" },
        expect: { accepted: true, reason: "accepted" },
      },
      {
        id: "bcc-eip712-missing-verifier-reject",
        description: "non-mock typed-data signatures require a verifier adapter",
        certificate: typedDataNoVerifier,
        verifier_context: { signature_adapter: "none" },
        expect: { accepted: false, reason: "signature_verifier_missing" },
      },
      {
        id: "bcc-eip712-bad-signer-reject",
        description: "the supplied signature adapter rejects a signature whose signer metadata was changed",
        certificate: typedDataBadSigner,
        verifier_context: { signature_adapter: "fixture-eip712" },
        expect: { accepted: false, reason: "signature_mismatch" },
      },
      {
        id: "bcc-vnet-cancellation-adapter-accept",
        description: "non-mock cancellation openings verify through the supplied cancellation adapter",
        certificate: cancellationAdapterGood,
        verifier_context: { cancellation_adapter: "fixture-vnet" },
        expect: { accepted: true, reason: "accepted" },
      },
      {
        id: "bcc-vnet-cancellation-missing-verifier-reject",
        description: "non-mock cancellation openings require a verifier adapter",
        certificate: cancellationAdapterNoVerifier,
        verifier_context: { cancellation_adapter: "none" },
        expect: { accepted: false, reason: "cancellation_verifier_missing" },
      },
      {
        id: "bcc-vnet-cancellation-bad-proof-reject",
        description: "the supplied cancellation adapter rejects an invalid cancellation proof digest",
        certificate: cancellationAdapterBadProof,
        verifier_context: { cancellation_adapter: "fixture-vnet" },
        expect: { accepted: false, reason: "cancellation_proof_mismatch" },
      },
      {
        id: "bcc-cancellation-false-net-reject",
        description: "records are signed but the cancellation opening says the committed records do not net to zero",
        certificate: falseNetPacket.certificate,
        private_witness: falseNetPacket.private_witness,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "cancellation_zero_opening" },
      },
      {
        id: "bcc-transcript-mismatch-reject",
        description: "event text changes after signatures and transcript hash are fixed",
        certificate: transcriptBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "transcript_hash_mismatch" },
      },
      {
        id: "bcc-authenticated-ecdh-mismatch-reject",
        description: "authenticated ECDH public edge tag no longer matches the signed ephemeral keys",
        certificate: dhBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "authenticated_dh_mismatch" },
      },
      {
        id: "bcc-private-witness-leak-reject",
        description: "public certificates must not carry private debit/credit vectors",
        certificate: leakBad,
        verifier_context: { seen_finality_tags: [] },
        expect: { accepted: false, reason: "private_witness_leak" },
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

function withFixtureCancellationAdapter(cert) {
  const out = clone(cert);
  out.cancellation_opening = fixtureProveCancellation(out);
  out.transcript_hash = transcriptHash(out);
  out.finality = buildFinality({
    transcript_hash: out.transcript_hash,
    log_ref: out.finality.log_ref,
    nullifier: out.finality.nullifier,
  });
  out.signatures = out.records.map((r) =>
    mockSignTranscript({
      party_id: r.party_id,
      public_key: `${r.party_id}:pub`,
      transcript_hash: out.transcript_hash,
    }),
  );
  return out;
}

function aggregateOpening(records) {
  return digestHex("aac/bcc/mock-aggregate-opening/1", records.map((record) => record.record_blinding));
}

function cancellationProofDigest(publicRecords, aggregate_opening, zero_opening) {
  return digestHex(
    "aac/bcc/mock-cancellation-opening/1",
    publicRecords.map((record) => record.record_commitment.value),
    aggregate_opening,
    zero_opening,
  );
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
