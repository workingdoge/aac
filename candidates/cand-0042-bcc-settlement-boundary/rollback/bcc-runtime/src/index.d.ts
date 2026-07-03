export declare const CERTIFICATE_SCHEMA = "aac.bcc.certificate.v1";
export declare const VECTOR_SCHEMA = "aac.bcc-demo.conformance.v1";
export declare const MOCK_COMMITMENT_SCHEME = "mock-vector-commitment/1";
export declare const MOCK_SIGNATURE_SCHEME = "mock-signature/1";
export declare const MOCK_DH_SCHEME = "mock-dh-edge/1";

export interface BccRecord {
  party_id: string;
  role: string;
  transition_ref: string;
  journal_commitment: string;
  basis_type_ids: string[];
  debit: number[];
  credit: number[];
  debit_blinding: string;
  credit_blinding: string;
  debit_commitment: { scheme: string; value: string };
  credit_commitment: { scheme: string; value: string };
}

export interface BccCertificate {
  schema: typeof CERTIFICATE_SCHEMA;
  event: Record<string, unknown>;
  basis_type_ids: string[];
  records: BccRecord[];
  vnet_certificate: Record<string, unknown>;
  dh_edge?: Record<string, unknown>;
  finality: { scheme: string; log_ref: string; nullifier: string; finality_tag: string };
  transcript_hash: string;
  signatures: Array<{ party_id: string; public_key: string; scheme: string; signature: string }>;
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
export declare function createRecord(input: Partial<BccRecord> & {
  party_id: string;
  role: string;
  transition_ref: string;
  journal_commitment: string;
  basis_type_ids: string[];
  debit: number[];
  credit: number[];
}): BccRecord;
export declare function createDhEdge(input?: {
  party_a?: string;
  party_b?: string;
  public_a?: string;
  public_b?: string;
}): Record<string, unknown>;
export declare function transcriptPayload(cert: BccCertificate): Record<string, unknown>;
export declare function transcriptHash(cert: BccCertificate): string;
export declare function mockSignTranscript(input: {
  party_id: string;
  public_key: string;
  transcript_hash: string;
}): { party_id: string; public_key: string; scheme: string; signature: string };
export declare function buildVnetCertificate(records: BccRecord[]): Record<string, unknown>;
export declare function buildFinality(input?: {
  transcript_hash?: string;
  log_ref?: string;
  nullifier?: string;
}): { scheme: string; log_ref: string; nullifier: string; finality_tag: string };
export declare function buildBilateralCertificate(input: {
  event?: Record<string, unknown>;
  records: Array<Partial<BccRecord> & {
    party_id: string;
    role: string;
    transition_ref: string;
    journal_commitment: string;
    debit: number[];
    credit: number[];
  }>;
  dh_edge?: Record<string, unknown>;
  signer_public_keys?: Record<string, string>;
  finality_context?: Record<string, unknown>;
}): BccCertificate;
export declare function verifyBilateralCertificate(cert: BccCertificate, opts?: {
  seenFinalityTags?: Set<string>;
  seen_finality_tags?: string[];
}): VerificationResult;
export declare function authorizeFinality(cert: BccCertificate): Record<string, unknown>;
export declare function amountTotals(records: BccRecord[]): [number[], number[]];
export declare function demoCertificate(): BccCertificate;
export declare function demoVectors(): Record<string, unknown>;
