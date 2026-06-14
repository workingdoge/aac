import type { FundraisePacket } from "../../fundraise-runtime/src/index.d.ts";
import type { VerifierReceipt, WorkflowPolicy } from "../../fundraise-workflow/src/index.d.ts";

export declare const PROVEKIT_ADAPTER_SCHEMA = "aac.fundraise-provekit-adapter.input.v1";
export declare const PROVEKIT_PROOF_SYSTEMS: readonly ["provekit-whir", "provekit-groth16"];
export declare const PROVEKIT_MODES: readonly ["native-cli", "browser-wasm", "service", "cre-workflow"];
export declare const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";
export declare const DEFAULT_PROVEKIT_BIN = "provekit-cli";

export interface ProveKitResult {
  accepted: boolean;
  reason?: string;
  proof_system: "provekit-whir" | "provekit-groth16";
  mode: "native-cli" | "browser-wasm" | "service" | "cre-workflow";
  proof?: Uint8Array | string | unknown;
  proof_digest?: string;
  proof_ref?: string;
  public_inputs: unknown;
  verifier_key_digest?: string;
  vk_digest?: string;
  timings_ms?: Record<string, number>;
}

export interface ProveKitNativeCliCommand {
  step: "prepare" | "prove" | "verify";
  executable: string;
  args: string[];
  cwd: string;
  env: Record<string, string | undefined>;
  timeout_ms: number;
  max_buffer: number;
}

export interface ProveKitNativeCliCommandResult {
  exit_code?: number;
  code?: number;
  stdout?: string;
  stderr?: string;
}

export interface ProveKitNativeCliInput {
  circuit_dir: string;
  prover_toml: string;
  public_inputs: unknown;
  provekit_bin?: string;
  cwd?: string;
  env?: Record<string, string | undefined>;
  prover_key?: string;
  verifier_key?: string;
  proof?: string;
  proof_ref?: string;
  proof_system?: ProveKitResult["proof_system"];
  prepare?: boolean;
  prove?: boolean;
  verify?: boolean;
  timeout_ms?: number;
  max_buffer?: number;
  run_command?: (command: ProveKitNativeCliCommand) => Promise<ProveKitNativeCliCommandResult>;
}

export declare class FundraiseProveKitAdapterError extends Error {
  readonly reason: string;
  readonly detail: Record<string, unknown>;
  constructor(reason: string, message?: string, detail?: Record<string, unknown>);
}

export declare function runProveKitNativeCli(input: ProveKitNativeCliInput): Promise<ProveKitResult & {
  accepted: true;
  reason: "accepted";
  proof_digest: string;
  proof_ref: string;
  verifier_key_digest: string;
  mode: "native-cli";
}>;
export declare function buildProveKitVerifierReceiptFromNativeCli(input: {
  packet: FundraisePacket;
  cli: Omit<ProveKitNativeCliInput, "public_inputs"> & { public_inputs?: unknown };
  verifier_id?: string;
  verifier_profile?: string;
}): Promise<VerifierReceipt & {
  verifier_key_digest: string;
  timings_ms: Record<string, number>;
  adapter_schema: typeof PROVEKIT_ADAPTER_SCHEMA;
}>;
export declare function buildProveKitVerifierReceipt(input: {
  packet: FundraisePacket;
  provekit: ProveKitResult;
  verifier_id?: string;
  verifier_profile?: string;
}): VerifierReceipt & {
  verifier_key_digest: string;
  timings_ms: Record<string, number>;
  adapter_schema: typeof PROVEKIT_ADAPTER_SCHEMA;
};
export declare function verifyProveKitVerifierReceipt(
  receipt: VerifierReceipt | unknown,
  input: { packet: FundraisePacket; policy?: Partial<WorkflowPolicy> },
): { accepted: true; reason: "accepted"; verifier_receipt: VerifierReceipt } | { accepted: false; reason: string };
export declare function normalizeProveKitResult(provekit: ProveKitResult): {
  proof_system: ProveKitResult["proof_system"];
  mode: ProveKitResult["mode"];
  public_inputs: unknown;
  proof_digest: string;
  proof_ref: string;
  verifier_key_digest: string;
  timings_ms: Record<string, number>;
};
