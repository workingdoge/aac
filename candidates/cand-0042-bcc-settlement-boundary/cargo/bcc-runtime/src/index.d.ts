export declare const CERTIFICATE_SCHEMA = "aac.bcc.certificate.v1";
export declare const WITNESS_SCHEMA = "aac.bcc.private-witness.v1";
export declare const PACKET_SCHEMA = "aac.bcc.packet.v1";
export declare const VECTOR_SCHEMA = "aac.bcc-demo.conformance.v1";
export declare const MOCK_RECORD_COMMITMENT_SCHEME = "mock-record-commitment/1";
export declare const MOCK_CANCELLATION_SCHEME = "mock-cancellation-opening/1";
export declare const MOCK_SIGNATURE_SCHEME = "mock-signature/1";
export declare const MOCK_AUTHENTICATED_ECDH_SCHEME = "mock-authenticated-ecdh/1";
export declare const MOCK_COMMITMENT_SCHEME = "mock-record-commitment/1";
export declare const MOCK_DH_SCHEME = "mock-authenticated-ecdh/1";

export interface Commitment {
  scheme: string;
  value: string;
}

export interface BccPrivateRecord {
  party_id: string;
  role: string;
  transition_ref: string;
  journal_commitment: string;
  basis_type_ids: string[];
  debit: number[];
  credit: number[];
  record_blinding: string;
  record_commitment: Commitment;
}

export interface BccPublicRecord {
  party_id: string;
  role: string;
  transition_ref: string;
  journal_commitment: string;
  basis_type_ids: string[];
  record_commitment: Commitment;
}

export interface BccPrivateWitness {
  schema: typeof WITNESS_SCHEMA;
  records: Array<{
    party_id: string;
    role: string;
    basis_type_ids: string[];
    debit: number[];
    credit: number[];
    record_blinding: string;
  }>;
  aggregate_opening: string;
}

export interface CancellationOpening {
  scheme: string;
  commitment_scheme: string;
  aggregate_opening: string;
  zero_opening: boolean;
  proof_digest: string;
  record_count: number;
}

export interface AuthenticatedDh {
  scheme: string;
  ephemeral_public_keys: Record<string, string>;
  kdf: string;
  transcript_binding: string;
  public_edge_tag: string;
}

export interface BccCertificate {
  schema: typeof CERTIFICATE_SCHEMA;
  event: Record<string, unknown>;
  basis_type_ids: string[];
  records: BccPublicRecord[];
  cancellation_opening: CancellationOpening;
  authenticated_dh?: AuthenticatedDh;
  finality: { scheme: string; log_ref: string; nullifier: string; finality_tag: string };
  transcript_hash: string;
  signatures: Array<{ party_id: string; public_key: string; scheme: string; signature: string }>;
}

export interface BccPacket {
  schema: typeof PACKET_SCHEMA;
  certificate: BccCertificate;
  private_witness: BccPrivateWitness;
}

export type VerificationResult =
  | { accepted: true; reason: "accepted"; authorization: Record<string, unknown> }
  | { accepted: false; reason: string };

export declare class BccVerificationError extends Error {
  readonly reason: string;
  constructor(reason: string, message?: string);
}

export declare function canonical(value: unknown): string;
export declare function digestHex(label: string, ...parts: unknown[]): string;
export declare function createBilateralEvent(input?: Record<string, unknown>): Record<string, unknown>;
export declare function signedVector(record: Pick<BccPrivateRecord, "debit" | "credit">): number[];
export declare function mockCommitRecord(input: {
  basis_type_ids: string[];
  debit: number[];
  credit: number[];
  blinding: string;
}): Commitment;
export declare function mockCommitVector(input: {
  basis_type_ids: string[];
  vector: number[];
  blinding: string;
}): Commitment;
export declare function createRecord(input: Partial<BccPrivateRecord> & {
  party_id: string;
  role: string;
  transition_ref: string;
  journal_commitment: string;
  basis_type_ids: string[];
  debit: number[];
  credit: number[];
  record_blinding?: string;
  blinding?: string;
}): BccPrivateRecord;
export declare function publicRecord(record: BccPrivateRecord): BccPublicRecord;
export declare function createAuthenticatedDh(input?: {
  party_a?: string;
  party_b?: string;
  public_a?: string;
  public_b?: string;
}): AuthenticatedDh;
export declare function createDhEdge(input?: {
  party_a?: string;
  party_b?: string;
  public_a?: string;
  public_b?: string;
}): AuthenticatedDh;
export declare function buildPrivateWitness(records: BccPrivateRecord[]): BccPrivateWitness;
export declare function buildCancellationOpening(records: BccPrivateRecord[], publicRecords?: BccPublicRecord[]): CancellationOpening;
export declare function buildVnetCertificate(records: BccPrivateRecord[]): CancellationOpening;
export declare function transcriptPayload(cert: BccCertificate): Record<string, unknown>;
export declare function transcriptHash(cert: BccCertificate): string;
export declare function mockSignTranscript(input: {
  party_id: string;
  public_key: string;
  transcript_hash: string;
}): { party_id: string; public_key: string; scheme: string; signature: string };
export declare function buildFinality(input?: {
  transcript_hash?: string;
  log_ref?: string;
  nullifier?: string;
}): { scheme: string; log_ref: string; nullifier: string; finality_tag: string };
export declare function buildBilateralPacket(input: {
  event?: Record<string, unknown>;
  records: Array<Partial<BccPrivateRecord> & {
    party_id: string;
    role: string;
    transition_ref: string;
    journal_commitment: string;
    debit: number[];
    credit: number[];
  }>;
  authenticated_dh?: AuthenticatedDh;
  dh_edge?: AuthenticatedDh;
  signer_public_keys?: Record<string, string>;
  finality_context?: Record<string, unknown>;
}): BccPacket;
export declare function buildBilateralCertificate(input: Parameters<typeof buildBilateralPacket>[0]): BccCertificate;
export declare function verifyBilateralCertificate(cert: BccCertificate, opts?: {
  seenFinalityTags?: Set<string>;
  seen_finality_tags?: string[];
}): VerificationResult;
export declare function verifyBilateralPacket(packet: BccPacket, opts?: {
  seenFinalityTags?: Set<string>;
  seen_finality_tags?: string[];
}): VerificationResult;
export declare function authorizeFinality(cert: BccCertificate): Record<string, unknown>;
export declare function amountTotals(records: Array<Pick<BccPrivateRecord, "debit" | "credit">>): [number[], number[]];
export declare function amountNet(records: Array<Pick<BccPrivateRecord, "debit" | "credit">>): number[];
export declare function demoPacket(): BccPacket;
export declare function demoCertificate(): BccCertificate;
export declare function demoVectors(): Record<string, unknown>;
