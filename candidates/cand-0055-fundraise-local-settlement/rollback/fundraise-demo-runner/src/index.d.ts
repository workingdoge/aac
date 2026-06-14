import type { ProveKitNativeCliCommand, ProveKitNativeCliCommandResult } from "../../fundraise-provekit-adapter/src/index.d.ts";
import type { FundraisePacket, VerifyOptions } from "../../fundraise-runtime/src/index.d.ts";
import type { WorkflowPolicy, WorkflowReceipt, SettlementAction, VerifierReceipt } from "../../fundraise-workflow/src/index.d.ts";

export declare const FUNDRAISE_DEMO_RUNNER_SCHEMA = "aac.fundraise-demo-runner.receipt.v1";
export declare const DEFAULT_VECTOR_ID = "fundraise-demo-good";
export declare const DEFAULT_PROVEKIT_PACKAGE = "world-app/provekit-vnet";
export declare const DEFAULT_PROVEKIT_PROOF = "proof.np";
export declare const DEFAULT_PROVEKIT_PROVER_KEY = "aac_vnet_provekit.pkp";
export declare const DEFAULT_PROVEKIT_VERIFIER_KEY = "aac_vnet_provekit.pkv";

export declare class FundraiseDemoRunnerError extends Error {
  readonly reason: string;
  readonly detail: Record<string, unknown>;
  constructor(reason: string, message?: string, detail?: Record<string, unknown>);
}

export interface FundraiseDemoRunnerInput {
  repo_root?: string;
  fixture_path?: string;
  vector_id?: string;
  packet?: FundraisePacket;
  circuit_dir?: string;
  work_dir?: string;
  keep_workdir?: boolean;
  provekit_bin?: string;
  prover_key?: string;
  verifier_key?: string;
  proof?: string;
  proof_ref?: string;
  timeout_ms?: number;
  env?: Record<string, string | undefined>;
  run_command?: (command: ProveKitNativeCliCommand) => Promise<ProveKitNativeCliCommandResult>;
  verifier_id?: string;
  workflow_policy?: Partial<WorkflowPolicy> & { authorizer_policy?: Partial<WorkflowPolicy["authorizer_policy"]> };
  recipient_overrides?: Record<string, string>;
  verify_options?: VerifyOptions;
}

export interface FundraiseDemoReceipt {
  schema: typeof FUNDRAISE_DEMO_RUNNER_SCHEMA;
  accepted: true;
  reason: "accepted";
  vector_id: string;
  packet_round_id: string | null;
  provekit: {
    mode: string;
    proof_system: string;
    proof_ref: string;
    proof_digest: string;
    verifier_key_digest: string;
    timings_ms: Record<string, number>;
  };
  verifier_receipt: VerifierReceipt & {
    verifier_key_digest: string;
    timings_ms: Record<string, number>;
  };
  workflow_receipt: WorkflowReceipt & { accepted: true };
  settlement_action: SettlementAction;
  workdir: string | null;
}

export declare function runFundraiseDemo(input?: FundraiseDemoRunnerInput): Promise<FundraiseDemoReceipt>;
export declare function loadFundraiseDemoPacket(input?: {
  repo_root?: string;
  fixture_path?: string;
  vector_id?: string;
}): Promise<FundraisePacket>;
export declare function prepareProveKitWorkdir(input?: {
  repo_root?: string;
  circuit_dir?: string;
  work_dir?: string;
  keep_workdir?: boolean;
}): Promise<{
  work_dir: string;
  circuit_dir: string;
  home_dir: string;
  keep_workdir: boolean;
}>;
