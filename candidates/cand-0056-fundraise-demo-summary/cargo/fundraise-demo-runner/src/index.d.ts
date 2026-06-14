import type { ProveKitNativeCliCommand, ProveKitNativeCliCommandResult } from "../../fundraise-provekit-adapter/src/index.d.ts";
import type { FundraisePacket, VerifyOptions } from "../../fundraise-runtime/src/index.d.ts";
import type { WorkflowPolicy, WorkflowReceipt, SettlementAction, VerifierReceipt } from "../../fundraise-workflow/src/index.d.ts";

export declare const FUNDRAISE_DEMO_RUNNER_SCHEMA = "aac.fundraise-demo-runner.receipt.v1";
export declare const DEFAULT_VECTOR_ID = "fundraise-demo-good";
export declare const DEFAULT_PROVEKIT_PACKAGE = "world-app/provekit-vnet";
export declare const DEFAULT_PROVEKIT_PROOF = "proof.np";
export declare const DEFAULT_PROVEKIT_PROVER_KEY = "aac_vnet_provekit.pkp";
export declare const DEFAULT_PROVEKIT_VERIFIER_KEY = "aac_vnet_provekit.pkv";
export declare const FUNDRAISE_DEMO_SUMMARY_SCHEMA = "aac.fundraise-demo-runner.summary.v1";
export declare const FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA = "aac.fundraise-demo-runner.local-settlement.v1";
export declare const DEFAULT_REGISTRY_PACKAGE = "registry";
export declare const DEFAULT_LOCAL_RPC_URL = "http://127.0.0.1:8545";
export declare const DEFAULT_ANVIL_DEPLOYER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
export declare const DEFAULT_DEMO_AUTHORIZER_PRIVATE_KEY =
  "0x00000000000000000000000000000000000000000000000000000000000a11ce";

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
  registry_dir?: string;
  rpc_url?: string;
  forge_bin?: string;
  cast_bin?: string;
  solc_bin?: string;
  deployer_private_key?: string;
  authorizer_private_key?: string;
  token_name?: string;
  token_symbol?: string;
  foundry_command?: (command: FoundryCommand) => Promise<FoundryCommandResult>;
}

export interface FundraiseDemoReceipt {
  schema: typeof FUNDRAISE_DEMO_RUNNER_SCHEMA;
  accepted: true;
  reason: "accepted";
  vector_id: string;
  packet_round_id: string | null;
  public_inputs: Record<string, unknown>;
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
  summary: FundraiseDemoSummary;
}

export interface FundraiseDemoSummary {
  schema: typeof FUNDRAISE_DEMO_SUMMARY_SCHEMA;
  accepted: boolean;
  status: "authorized-pending-signature" | "settled-local";
  vector_id: string;
  round_id: string | null;
  issuer_name: string | null;
  economics: {
    settlement_amount_total: number | null;
    issued_unit_total: number | null;
    recipient_count: number;
  };
  commitments: {
    transition_set: string | null;
    vnet_public: string | null;
    subscription_set: string | null;
    bcc_set: string | null;
    bridge_settlement: string | null;
    mint_recipient_set: string | null;
    prev_balance_sheet_root: string | null;
    next_balance_sheet_root: string | null;
    prev_cap_table_root: string | null;
    next_cap_table_root: string | null;
  };
  proof: {
    mode: string | null;
    proof_system: string | null;
    proof_digest: string | null;
    verifier_key_digest: string | null;
    timings_ms: Record<string, number>;
  };
  workflow: {
    workflow_id: string | null;
    workflow_engine: string | null;
    verifier_receipt_digest: string | null;
    authorizer_receipt_digest: string | null;
    action_digest: string | null;
    signature_status: "pending" | "submitted" | string;
  };
  settlement: {
    chain_id: number | null;
    token_contract: string | null;
    settlement_contract: string | null;
    authorizer: string | null;
    settlement_digest: string | null;
    transaction_hash: string | null;
    total_supply: number | null;
    balances: Array<{ account: string; amount: number }>;
  };
  claims: string[];
  caveats: string[];
}

export interface FoundryCommand {
  executable: string;
  args: string[];
  cwd?: string;
  env?: Record<string, string | undefined>;
  timeout_ms?: number;
  max_buffer?: number;
}

export interface FoundryCommandResult {
  exit_code?: number;
  code?: number;
  stdout: string;
  stderr?: string;
}

export interface LocalSettlementExecution {
  schema: typeof FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA;
  rpc_url: string;
  token_contract: string;
  settlement_contract: string;
  authorizer: string;
  round_id_hash: string;
  settlement_digest: string;
  signature: string;
  transaction_hash: string | null;
  balances: Array<{ account: string; amount: number }>;
  total_supply: number;
}

export type FundraiseLocalSettlementReceipt = FundraiseDemoReceipt & {
  local_settlement: LocalSettlementExecution;
  summary: FundraiseDemoSummary & { status: "settled-local" };
};

export declare function runFundraiseDemo(input?: FundraiseDemoRunnerInput): Promise<FundraiseDemoReceipt>;
export declare function buildFundraiseDemoVerifierReceipt(input?: FundraiseDemoRunnerInput): Promise<{
  packet: FundraisePacket;
  verifier_receipt: VerifierReceipt & {
    verifier_key_digest: string;
    timings_ms: Record<string, number>;
  };
  workdir: string | null;
}>;
export declare function runFundraiseDemoLocalSettlement(
  input?: FundraiseDemoRunnerInput,
): Promise<FundraiseLocalSettlementReceipt>;
export declare function buildFundraiseDemoSummary(receipt: FundraiseDemoReceipt): FundraiseDemoSummary;
export declare function prepareFoundrySettlement(input?: FundraiseDemoRunnerInput): Promise<{
  rpc_url: string;
  registry_dir: string;
  cast_bin: string;
  forge_bin: string;
  solc_bin: string;
  deployer_private_key: string;
  authorizer_private_key: string;
  authorizer: string;
  token_contract: string;
  token_deploy_tx: string;
  settlement_contract: string;
  settlement_deploy_tx: string;
  round_id_hash: string;
  run_command: (command: FoundryCommand) => Promise<FoundryCommandResult>;
}>;
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
