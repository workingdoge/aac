export declare const PROFILE_ID = "vnet-bn254-g1/1";
export declare const VECTOR_SCHEMA = "aac.vnet-bn254-g1.conformance.v1";
export declare const LINK_SCHEMA = "aac.vnet-link-ref.conformance.v1";
export declare const P: bigint;
export declare const R: bigint;

export type VerificationResult =
  | { accepted: true; reason: "accepted" }
  | { accepted: false; reason: string };

export interface VnetPoint {
  x: string;
  y: string;
  uncompressed: string;
}

export interface VnetAtom {
  transition_ref: string;
  journal_commitment: string;
  profile_id: string;
  basis_type_ids: string[];
  basis_commitment: string;
  debit: number[];
  credit: number[];
  debit_blinding: number | string;
  credit_blinding: number | string;
  debit_commitment: VnetPoint;
  credit_commitment: VnetPoint;
  transition_link?: { opening_matches_journal?: boolean };
}

export interface VnetVector {
  profile_id: string;
  basis_type_ids: string[];
  basis_commitment: string;
  atoms: VnetAtom[];
  aggregate_blinding: string;
  aggregate_opening: VnetPoint;
  transition_set_commitment: string;
  commitment_set_commitment: string;
}

export interface VnetLink {
  transition_report: {
    schema?: string;
    accepted: Array<{
      transition_ref: string;
      target: string;
      journal_commitment: string;
    }>;
  };
  vnet: VnetVector;
  link_certificates: Array<Record<string, unknown>>;
}

export declare class VnetVerificationError extends Error {
  readonly reason: string;
  constructor(reason: string, message?: string);
}

export declare function canonical(value: unknown): string;
export declare function digestHex(label: string, ...parts: unknown[]): string;
export declare function scalarHash(label: string, ...parts: unknown[]): bigint;
export declare function basisCommitment(basisTypeIds: string[]): string;
export declare function encodePoint(pt: [bigint, bigint]): VnetPoint;
export declare function decodePoint(obj: VnetPoint): [bigint, bigint];
export declare function commitVector(vec: Array<number | string>, rho: number | string, basisTypeIds: string[]): [bigint, bigint];
export declare function foldScalar(label: string, items: unknown): string;
export declare function verifyVnetBn254Vector(vnet: VnetVector): VerificationResult;
export declare function certificateFor(atom: VnetAtom): Record<string, unknown>;
export declare function transitionReportFor(vnet: VnetVector): VnetLink["transition_report"];
export declare function verifyVnetLink(vnetLink: VnetLink): VerificationResult;
export declare function vnetPublic(vnetLink: VnetLink): Record<string, unknown>;
