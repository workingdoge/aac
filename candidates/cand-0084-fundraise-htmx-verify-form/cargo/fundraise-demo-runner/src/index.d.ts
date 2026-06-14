import type { ProveKitNativeCliCommand, ProveKitNativeCliCommandResult } from "../../fundraise-provekit-adapter/src/index.d.ts";
import type { FundraisePacket, VerifyOptions } from "../../fundraise-runtime/src/index.d.ts";
import type { WorkflowPolicy, WorkflowReceipt, SettlementAction, VerifierReceipt } from "../../fundraise-workflow/src/index.d.ts";

export declare const FUNDRAISE_DEMO_RUNNER_SCHEMA = "aac.fundraise-demo-runner.receipt.v1";
export declare const DEFAULT_VECTOR_ID = "fundraise-demo-good";
export declare const DEFAULT_PROVEKIT_PACKAGE = "world-app/provekit-vnet";
export declare const DEFAULT_PROVEKIT_PROOF = "proof.np";
export declare const DEFAULT_PROVEKIT_PROVER_KEY = "aac_vnet_provekit.pkp";
export declare const DEFAULT_PROVEKIT_VERIFIER_KEY = "aac_vnet_provekit.pkv";
export declare const DEFAULT_BALANCE_SHEET_PROVEKIT_PACKAGE = "world-app/provekit-balance-sheet";
export declare const DEFAULT_BALANCE_SHEET_PROOF = "balance-sheet-proof.np";
export declare const DEFAULT_BALANCE_SHEET_PROVER_KEY = "aac_balance_sheet_provekit.pkp";
export declare const DEFAULT_BALANCE_SHEET_VERIFIER_KEY = "aac_balance_sheet_provekit.pkv";
export declare const FUNDRAISE_BALANCE_SHEET_PACKET_SCHEMA =
  "aac.fundraise-demo.balance-sheet-proof-packet.v1";
export declare const FUNDRAISE_DEMO_SUMMARY_SCHEMA = "aac.fundraise-demo-runner.summary.v1";
export declare const FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA = "aac.fundraise-demo-runner.local-settlement.v1";
export declare const FUNDRAISE_DEMO_PREVIEW_SCHEMA = "aac.fundraise-demo-runner.preview.v1";
export declare const DEFAULT_REGISTRY_PACKAGE = "registry";
export declare const DEFAULT_LOCAL_RPC_URL = "http://127.0.0.1:8545";
export declare const FUNDRAISE_DEMO_SERVER_SCHEMA = "aac.fundraise-demo-runner.server.v1";
export declare const FUNDRAISE_DEMO_PROOF_SESSION_SCHEMA =
  "aac.fundraise-demo-runner.proof-session.v1";
export declare const FUNDRAISE_DEMO_VERIFY_RESULT_SCHEMA =
  "aac.fundraise-demo-runner.verify-result.v1";
export declare const DEFAULT_FUNDRAISE_DEMO_SERVER_HOST = "127.0.0.1";
export declare const DEFAULT_FUNDRAISE_DEMO_SERVER_PORT = 8787;
export declare const DEFAULT_FUNDRAISE_PROOF_SESSION_TTL_MS: number;
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
  balance_sheet_circuit_dir?: string;
  balance_sheet_work_dir?: string;
  balance_sheet_prover_key?: string;
  balance_sheet_verifier_key?: string;
  balance_sheet_proof?: string;
  balance_sheet_proof_ref?: string;
  balance_sheet_verifier_id?: string;
  balance_sheet_verifier_profile?: string;
  balance_sheet_salt?: number | string | bigint;
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
  variable_fill_units?: number;
  variableFillUnits?: number;
  batch_units?: number;
  batchUnits?: number;
  proof_session_ttl_ms?: number;
}

export interface FundraiseDemoServerInput extends FundraiseDemoRunnerInput {
  host?: string;
  port?: number;
  static_dir?: string;
  cors_origin?: string;
  settle_local?: boolean;
}

export declare function buildFundraiseDemoCorsHeaders(cors_origin?: string): Record<string, string>;
export declare function resolveFundraiseStaticPath(static_dir: string, pathname: string): Promise<string | null>;
export declare function fundraiseStaticContentType(pathname: string): string;
export declare function attachFundraiseBalanceSheetRoots(packet: FundraisePacket, input?: FundraiseDemoRunnerInput): FundraisePacket;
export declare function buildBalanceSheetProofPacket(
  packet: FundraisePacket,
  proof_input?: Record<string, unknown>,
): FundraiseBalanceSheetProofPacket;

export interface FundraiseBalanceSheetProofPacket {
  schema: typeof FUNDRAISE_BALANCE_SHEET_PACKET_SCHEMA;
  profile_id: string;
  commitment_profile: string;
  round_id: string | null;
  issuer_name: string | null;
  fundraise_packet_commitment: string;
  public_inputs: Record<string, string>;
  roots: Record<string, string>;
  rows: Array<Record<string, string | number>>;
  boundary: string;
}

export interface FundraiseDemoReceipt {
  schema: typeof FUNDRAISE_DEMO_RUNNER_SCHEMA;
  accepted: true;
  reason: "accepted";
  vector_id: string;
  packet_round_id: string | null;
  packet_projection: {
    round_policy: {
      round_id: string | null;
      issuer_name: string | null;
      settlement_asset_type_id: string | null;
      issued_unit_type_id: string | null;
      price_numerator: number | null;
      price_denominator: number | null;
      max_issued_units: number | null;
      max_settlement_amount: number | null;
    };
    subscriptions: Array<{
      subscription_id: string | null;
      investor_id: string | null;
      settlement_ref: string | null;
      settlement_amount: number | null;
      issued_units: number | null;
      mint_recipient: string | null;
    }>;
  };
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
  balance_sheet_packet: FundraiseBalanceSheetProofPacket;
  balance_sheet_verifier_receipt: VerifierReceipt & {
    verifier_key_digest: string;
    timings_ms: Record<string, number>;
  };
  balance_sheet_state: Record<string, unknown>;
  balance_sheet_provekit: {
    mode: string | null;
    proof_system: string | null;
    proof_ref: string | null;
    proof_digest: string | null;
    verifier_key_digest: string | null;
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
  status: "ready-to-run" | "authorized-pending-signature" | "settled-local";
  vector_id: string;
  round_id: string | null;
  issuer_name: string | null;
  metrics: Array<{
    value: string;
    label: string;
  }>;
  order: {
    headline: string;
    price_label: string;
    settlement_asset: string;
    issued_unit: string;
    issued_unit_noun: string;
    price_per_unit: number | null;
    max_settlement_amount: number | null;
    max_issued_units: number | null;
    filled_issued_units: number | null;
    open_issued_units: number | null;
  };
  fills: Array<{
    party: string;
    subscription_id: string | null;
    settlement_ref: string | null;
    settlement_amount: number | null;
    settlement_label: string;
    issued_units: number | null;
    issued_label: string;
    recipient: string | null;
  }>;
  opening_balances: Array<{
    label: string;
    value: string;
  }>;
  reconciliation: {
    accepted: boolean;
    rows: Array<{
      line: string;
      opening: string;
      delta: string;
      closing: string;
    }>;
  };
  verifier: {
    accepted: boolean;
    status: "accepted" | "not-run" | string;
    status_label: string;
    target_label: string;
    verifier_id: string | null;
    verifier_profile: string | null;
    proof_system: string | null;
    mode: string | null;
    packet_commitment: string | null;
    public_inputs_commitment: string | null;
    proof_ref: string | null;
    proof_digest: string | null;
    verifier_key_digest: string | null;
    receipt_digest: string | null;
    adapter_schema: string | null;
    timings_ms: Record<string, number>;
    boundary: string;
  };
  balance_sheet: {
    accepted: boolean;
    status: "accepted" | "not-run" | string;
    status_label: string;
    target_label: string;
    verifier_id: string | null;
    verifier_profile: string | null;
    proof_system: string | null;
    mode: string | null;
    fundraise_packet_commitment: string | null;
    packet_commitment: string | null;
    public_inputs_commitment: string | null;
    proof_ref: string | null;
    proof_digest: string | null;
    verifier_key_digest: string | null;
    receipt_digest: string | null;
    adapter_schema: string | null;
    timings_ms: Record<string, number>;
    roots: Record<string, string | null>;
    public_inputs: Record<string, unknown>;
    rows: Array<Record<string, string | number>>;
    boundary: string;
  };
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

export declare function buildFundraiseDemoBatchPacket(packet: FundraisePacket, input?: FundraiseDemoRunnerInput): FundraisePacket;
export declare function runFundraiseDemo(input?: FundraiseDemoRunnerInput): Promise<FundraiseDemoReceipt>;
export declare function runFundraiseDemoServerAction(input?: FundraiseDemoServerInput, request?: {
  path?: string;
  body?: Record<string, unknown>;
}): Promise<{
  schema: typeof FUNDRAISE_DEMO_SERVER_SCHEMA;
  accepted: true;
  reason: "accepted";
  mode: "live-proof" | "live-proof+local-settlement";
  elapsed_ms: number;
  receipt: FundraiseDemoReceipt | FundraiseLocalSettlementReceipt;
  summary: FundraiseDemoSummary;
}>;
export declare function runFundraiseDemoProveAction(input?: FundraiseDemoServerInput, request?: {
  path?: string;
  body?: Record<string, unknown>;
}): Promise<{
  schema: typeof FUNDRAISE_DEMO_SERVER_SCHEMA;
  accepted: true;
  reason: "accepted";
  mode: "proof-generated";
  elapsed_ms: number;
  proof_id: string;
  proof_session: FundraiseDemoProofSession;
  receipt: FundraiseDemoReceipt;
  summary: FundraiseDemoSummary;
}>;
export declare function runFundraiseDemoVerifyAction(input?: FundraiseDemoServerInput, request?: {
  path?: string;
  body?: Record<string, unknown>;
}): Promise<FundraiseDemoVerifyResult>;
export declare function previewFundraiseDemo(input?: FundraiseDemoRunnerInput): Promise<{
  schema: typeof FUNDRAISE_DEMO_PREVIEW_SCHEMA;
  accepted: true;
  reason: "accepted";
  mode: "preview";
  elapsed_ms: number;
  receipt: FundraiseDemoReceipt;
  summary: FundraiseDemoSummary;
}>;
export declare function serveFundraiseDemo(input?: FundraiseDemoServerInput): Promise<{
  schema: typeof FUNDRAISE_DEMO_SERVER_SCHEMA;
  host: string;
  port: number;
  url: string;
  server: unknown;
  close: () => Promise<void>;
}>;
export declare function buildFundraiseDemoVerifierReceipt(input?: FundraiseDemoRunnerInput): Promise<{
  packet: FundraisePacket;
  verifier_receipt: VerifierReceipt & {
    verifier_key_digest: string;
    timings_ms: Record<string, number>;
  };
  workdir: string | null;
  balance_sheet_workdir: string | null;
}>;

export interface FundraiseDemoProofSession {
  schema: typeof FUNDRAISE_DEMO_PROOF_SESSION_SCHEMA;
  proof_id: string;
  expires_at: string;
  verify_fields: Record<string, string>;
}

export type FundraiseDemoVerifyResult = {
  schema: typeof FUNDRAISE_DEMO_VERIFY_RESULT_SCHEMA;
  accepted: boolean;
  reason: string;
  mode: "form-verify";
  proof_id: string | null;
  elapsed_ms: number;
  proof_session?: FundraiseDemoProofSession;
  receipt?: FundraiseDemoReceipt;
  summary?: FundraiseDemoSummary;
  verification?: {
    status: "accepted";
    fields: Record<string, string>;
  };
  detail?: Record<string, unknown>;
};
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
