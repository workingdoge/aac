import { cp, mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { buildProveKitVerifierReceiptFromNativeCli } from "../../fundraise-provekit-adapter/src/index.mjs";
import {
  authorizeFundraiseWorkflow,
  createWorkflowPolicy,
  verifyWorkflowReceipt,
} from "../../fundraise-workflow/src/index.mjs";

export const FUNDRAISE_DEMO_RUNNER_SCHEMA = "aac.fundraise-demo-runner.receipt.v1";
export const DEFAULT_VECTOR_ID = "fundraise-demo-good";
export const DEFAULT_PROVEKIT_PACKAGE = "world-app/provekit-vnet";
export const DEFAULT_PROVEKIT_PROOF = "proof.np";
export const DEFAULT_PROVEKIT_PROVER_KEY = "aac_vnet_provekit.pkp";
export const DEFAULT_PROVEKIT_VERIFIER_KEY = "aac_vnet_provekit.pkv";
export const FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA = "aac.fundraise-demo-runner.local-settlement.v1";
export const DEFAULT_REGISTRY_PACKAGE = "registry";
export const DEFAULT_LOCAL_RPC_URL = "http://127.0.0.1:8545";
export const DEFAULT_ANVIL_DEPLOYER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
export const DEFAULT_DEMO_AUTHORIZER_PRIVATE_KEY =
  "0x00000000000000000000000000000000000000000000000000000000000a11ce";

export class FundraiseDemoRunnerError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseDemoRunnerError";
    this.reason = reason;
    this.detail = detail;
  }
}

export async function runFundraiseDemo(input = {}) {
  const proof = await buildFundraiseDemoVerifierReceipt(input);
  const workflowReceipt = buildLiveWorkflowReceipt({
    packet: proof.packet,
    verifier_receipt: proof.verifier_receipt,
    workflow_policy: input.workflow_policy,
    recipient_overrides: input.recipient_overrides,
    verify_options: input.verify_options,
  });
  return buildDemoReceipt({
    input,
    packet: proof.packet,
    verifier_receipt: proof.verifier_receipt,
    workflow_receipt: workflowReceipt,
    workdir: proof.workdir,
  });
}

export async function buildFundraiseDemoVerifierReceipt(input = {}) {
  const repoRoot = resolve(input.repo_root ?? defaultRepoRoot());
  const packet = input.packet ?? (await loadFundraiseDemoPacket({
    repo_root: repoRoot,
    fixture_path: input.fixture_path,
    vector_id: input.vector_id,
  }));
  const work = await prepareProveKitWorkdir({
    repo_root: repoRoot,
    circuit_dir: input.circuit_dir,
    work_dir: input.work_dir,
    keep_workdir: input.keep_workdir,
  });
  try {
    const verifierReceipt = await buildProveKitVerifierReceiptFromNativeCli({
      packet,
      cli: {
        provekit_bin: input.provekit_bin,
        circuit_dir: work.circuit_dir,
        cwd: work.circuit_dir,
        prover_toml: "Prover.toml",
        prover_key: input.prover_key ?? DEFAULT_PROVEKIT_PROVER_KEY,
        verifier_key: input.verifier_key ?? DEFAULT_PROVEKIT_VERIFIER_KEY,
        proof: input.proof ?? DEFAULT_PROVEKIT_PROOF,
        proof_ref: input.proof_ref,
        timeout_ms: input.timeout_ms ?? 300_000,
        env: { HOME: work.home_dir, ...(input.env ?? {}) },
        run_command: input.run_command,
      },
      verifier_id: input.verifier_id ?? "aac-fundraise-demo-provekit",
    });
    return {
      packet,
      verifier_receipt: verifierReceipt,
      workdir: input.keep_workdir ? work.work_dir : null,
    };
  } finally {
    if (!input.keep_workdir) {
      await rm(work.work_dir, { recursive: true, force: true });
    }
  }
}

export async function runFundraiseDemoLocalSettlement(input = {}) {
  const repoRoot = resolve(input.repo_root ?? defaultRepoRoot());
  const proof = await buildFundraiseDemoVerifierReceipt({ ...input, repo_root: repoRoot });
  const foundry = await prepareFoundrySettlement({
    ...input,
    repo_root: repoRoot,
    packet: proof.packet,
  });
  const workflowReceipt = buildLiveWorkflowReceipt({
    packet: proof.packet,
    verifier_receipt: proof.verifier_receipt,
    workflow_policy: {
      ...(input.workflow_policy ?? {}),
      authorizer_policy: {
        ...(input.workflow_policy?.authorizer_policy ?? {}),
        token_contract: foundry.token_contract,
        settlement_contract: foundry.settlement_contract,
      },
    },
    recipient_overrides: input.recipient_overrides,
    verify_options: input.verify_options,
  });
  const execution = await submitSettlementAction({
    ...foundry,
    settlement_action: workflowReceipt.settlement_action,
  });
  return {
    ...buildDemoReceipt({
      input,
      packet: proof.packet,
      verifier_receipt: proof.verifier_receipt,
      workflow_receipt: workflowReceipt,
      workdir: proof.workdir,
    }),
    local_settlement: execution,
  };
}

export async function prepareFoundrySettlement(input = {}) {
  const repoRoot = resolve(input.repo_root ?? defaultRepoRoot());
  const registryDir = resolve(repoRoot, input.registry_dir ?? DEFAULT_REGISTRY_PACKAGE);
  const runCommand = normalizeFoundryCommand(input.foundry_command);
  const castBin = input.cast_bin ?? "cast";
  const forgeBin = input.forge_bin ?? "forge";
  const solcBin = input.solc_bin ?? "solc";
  const rpcUrl = input.rpc_url ?? DEFAULT_LOCAL_RPC_URL;
  const deployerPrivateKey = input.deployer_private_key ?? DEFAULT_ANVIL_DEPLOYER_PRIVATE_KEY;
  const authorizerPrivateKey = input.authorizer_private_key ?? DEFAULT_DEMO_AUTHORIZER_PRIVATE_KEY;
  const authorizer = await castWalletAddress({ castBin, authorizerPrivateKey, runCommand });
  const token = await forgeCreate({
    forgeBin,
    solcBin,
    registryDir,
    rpcUrl,
    privateKey: deployerPrivateKey,
    contract: "src/FundraiseSettlement.sol:FundraiseReceiptToken",
    constructorArgs: [input.token_name ?? "AAC SAFE Receipt", input.token_symbol ?? "AACSAFE"],
    runCommand,
  });
  const preliminaryPolicy = createWorkflowPolicy({
    ...(input.workflow_policy ?? {}),
    authorizer_policy: {
      ...(input.workflow_policy?.authorizer_policy ?? {}),
      token_contract: token.deployedTo,
    },
  });
  const roundIdHash = `0x${preliminaryPolicy.authorizer_policy.round_id_hash}`;
  const settlement = await forgeCreate({
    forgeBin,
    solcBin,
    registryDir,
    rpcUrl,
    privateKey: deployerPrivateKey,
    contract: "src/FundraiseSettlement.sol:FundraiseMintSettlement",
    constructorArgs: [authorizer, roundIdHash, token.deployedTo],
    runCommand,
  });
  await castSend({
    castBin,
    rpcUrl,
    privateKey: deployerPrivateKey,
    to: token.deployedTo,
    signature: "setMinter(address)",
    args: [settlement.deployedTo],
    runCommand,
  });
  return {
    rpc_url: rpcUrl,
    registry_dir: registryDir,
    cast_bin: castBin,
    forge_bin: forgeBin,
    solc_bin: solcBin,
    deployer_private_key: deployerPrivateKey,
    authorizer_private_key: authorizerPrivateKey,
    authorizer,
    token_contract: token.deployedTo,
    token_deploy_tx: token.transactionHash,
    settlement_contract: settlement.deployedTo,
    settlement_deploy_tx: settlement.transactionHash,
    round_id_hash: roundIdHash,
    run_command: runCommand,
  };
}

async function submitSettlementAction(input) {
  const auth = input.settlement_action?.args?.auth;
  if (!auth) {
    throw new FundraiseDemoRunnerError("settlement_action_missing");
  }
  const contractAuth = contractAuthorizationTuple(auth);
  const digest = await castCall({
    castBin: input.cast_bin,
    rpcUrl: input.rpc_url,
    to: input.settlement_contract,
    signature: "settlementDigest((bytes32,address,bytes32,bytes32,uint256,(address,uint256)[]))(bytes32)",
    args: [contractAuth],
    runCommand: input.run_command,
  });
  const signature = await castWalletSign({
    castBin: input.cast_bin,
    privateKey: input.authorizer_private_key,
    digest,
    runCommand: input.run_command,
  });
  const settleReceipt = await castSend({
    castBin: input.cast_bin,
    rpcUrl: input.rpc_url,
    privateKey: input.deployer_private_key,
    to: input.settlement_contract,
    signature: "settle((bytes32,address,bytes32,bytes32,uint256,(address,uint256)[]),bytes)",
    args: [contractAuth, signature],
    runCommand: input.run_command,
  });
  const balances = [];
  for (const recipient of auth.recipients) {
    balances.push({
      account: recipient.account,
      amount: Number(await castCall({
        castBin: input.cast_bin,
        rpcUrl: input.rpc_url,
        to: input.token_contract,
        signature: "balanceOf(address)(uint256)",
        args: [recipient.account],
        runCommand: input.run_command,
      })),
    });
  }
  const totalSupply = Number(await castCall({
    castBin: input.cast_bin,
    rpcUrl: input.rpc_url,
    to: input.token_contract,
    signature: "totalSupply()(uint256)",
    args: [],
    runCommand: input.run_command,
  }));
  return {
    schema: FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA,
    rpc_url: input.rpc_url,
    token_contract: input.token_contract,
    settlement_contract: input.settlement_contract,
    authorizer: input.authorizer,
    round_id_hash: input.round_id_hash,
    settlement_digest: digest,
    signature,
    transaction_hash: settleReceipt.transactionHash ?? settleReceipt.transaction_hash ?? null,
    balances,
    total_supply: totalSupply,
  };
}

function buildLiveWorkflowReceipt({
  packet,
  verifier_receipt,
  workflow_policy,
  recipient_overrides,
  verify_options,
}) {
  const workflowPolicy = createWorkflowPolicy({
    require_live_proof: true,
    ...(workflow_policy ?? {}),
  });
  const workflowReceipt = authorizeFundraiseWorkflow({
    packet,
    verifier_receipt,
    policy: workflowPolicy,
    recipient_overrides,
    verify_options,
  });
  if (!workflowReceipt.accepted) {
    throw new FundraiseDemoRunnerError("workflow_rejected", workflowReceipt.reason, {
      workflow_reason: workflowReceipt.reason,
    });
  }
  const workflowCheck = verifyWorkflowReceipt(workflowReceipt);
  if (!workflowCheck.accepted) {
    throw new FundraiseDemoRunnerError("workflow_receipt_invalid", workflowCheck.reason, {
      workflow_reason: workflowCheck.reason,
    });
  }
  return workflowReceipt;
}

function buildDemoReceipt({ input, packet, verifier_receipt, workflow_receipt, workdir }) {
  return {
    schema: FUNDRAISE_DEMO_RUNNER_SCHEMA,
    accepted: true,
    reason: "accepted",
    vector_id: input.vector_id ?? DEFAULT_VECTOR_ID,
    packet_round_id: packet.public_inputs?.round_id ?? packet.round_policy?.round_id ?? null,
    provekit: {
      mode: verifier_receipt.mode,
      proof_system: verifier_receipt.proof_system,
      proof_ref: verifier_receipt.proof_ref,
      proof_digest: verifier_receipt.proof_digest,
      verifier_key_digest: verifier_receipt.verifier_key_digest,
      timings_ms: verifier_receipt.timings_ms,
    },
    verifier_receipt,
    workflow_receipt,
    settlement_action: workflow_receipt.settlement_action,
    workdir,
  };
}

function contractAuthorizationTuple(auth) {
  return `(${[
    hex32(auth.round_id_hash),
    evmAddress(auth.token_contract),
    hex32(auth.runtime_authorization_digest),
    hex32(auth.runtime_mint_recipient_set_commitment),
    String(auth.issued_unit_total),
    `[${auth.recipients.map((recipient) => `(${evmAddress(recipient.account)},${recipient.amount})`).join(",")}]`,
  ].join(",")})`;
}

async function forgeCreate({
  forgeBin,
  solcBin,
  registryDir,
  rpcUrl,
  privateKey,
  contract,
  constructorArgs,
  runCommand,
}) {
  const result = await runCommand({
    executable: forgeBin,
    args: [
      "create",
      "--root",
      registryDir,
      "--use",
      solcBin,
      "--rpc-url",
      rpcUrl,
      "--private-key",
      privateKey,
      "--broadcast",
      "--json",
      contract,
      "--constructor-args",
      ...constructorArgs,
    ],
    cwd: registryDir,
  });
  return parseJsonResult(result.stdout, "forge_create_bad_json");
}

async function castSend({ castBin, rpcUrl, privateKey, to, signature, args, runCommand }) {
  const result = await runCommand({
    executable: castBin,
    args: ["send", "--json", "--rpc-url", rpcUrl, "--private-key", privateKey, to, signature, ...args],
  });
  return parseJsonResult(result.stdout, "cast_send_bad_json");
}

async function castCall({ castBin, rpcUrl, to, signature, args, runCommand }) {
  const result = await runCommand({
    executable: castBin,
    args: ["call", "--rpc-url", rpcUrl, to, signature, ...args],
  });
  return result.stdout.trim();
}

async function castWalletSign({ castBin, privateKey, digest, runCommand }) {
  const result = await runCommand({
    executable: castBin,
    args: ["wallet", "sign", "--no-hash", "--private-key", privateKey, digest],
  });
  return result.stdout.trim();
}

async function castWalletAddress({ castBin, authorizerPrivateKey, runCommand }) {
  const result = await runCommand({
    executable: castBin,
    args: ["wallet", "address", "--private-key", authorizerPrivateKey],
  });
  return result.stdout.trim();
}

function normalizeFoundryCommand(runCommand) {
  if (runCommand !== undefined) {
    if (typeof runCommand !== "function") {
      throw new FundraiseDemoRunnerError("bad_foundry_command");
    }
    return runCommand;
  }
  return defaultFoundryCommand;
}

async function defaultFoundryCommand(command) {
  const { execFile } = await import("node:child_process");
  return new Promise((resolveCommand, rejectCommand) => {
    execFile(
      command.executable,
      command.args,
      {
        cwd: command.cwd,
        env: { ...process.env, ...(command.env ?? {}) },
        timeout: command.timeout_ms ?? 120_000,
        maxBuffer: command.max_buffer ?? 32 * 1024 * 1024,
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stdout = stdout;
          error.stderr = stderr;
          rejectCommand(new FundraiseDemoRunnerError("foundry_command_failed", stderr || error.message, {
            executable: command.executable,
            args: command.args,
            exit_code: error.code ?? null,
            stdout,
            stderr,
          }));
          return;
        }
        resolveCommand({ exit_code: 0, stdout, stderr });
      },
    );
  });
}

function parseJsonResult(text, reason) {
  try {
    return JSON.parse(text);
  } catch (err) {
    throw new FundraiseDemoRunnerError(reason, reason, {
      cause: err?.message ?? "parse_error",
      text,
    });
  }
}

export async function loadFundraiseDemoPacket({
  repo_root = defaultRepoRoot(),
  fixture_path,
  vector_id = DEFAULT_VECTOR_ID,
} = {}) {
  const path = resolve(
    repo_root,
    fixture_path ?? "sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json",
  );
  const fixture = JSON.parse(await readFile(path, "utf8"));
  const vector = fixture.vectors?.find((item) => item.id === vector_id);
  if (!vector?.packet) {
    throw new FundraiseDemoRunnerError("vector_missing", `missing vector ${vector_id}`, {
      fixture_path: path,
      vector_id,
    });
  }
  return vector.packet;
}

export async function prepareProveKitWorkdir({
  repo_root = defaultRepoRoot(),
  circuit_dir,
  work_dir,
  keep_workdir = false,
} = {}) {
  const source = resolve(repo_root, circuit_dir ?? DEFAULT_PROVEKIT_PACKAGE);
  const workRoot = work_dir ? resolve(work_dir) : await mkdtemp(resolve(tmpdir(), "aac-fundraise-demo."));
  const target = resolve(workRoot, basename(source));
  await rm(target, { recursive: true, force: true });
  await cp(source, target, {
    recursive: true,
    filter: (src) => shouldCopyCircuitPath(source, src),
  });
  await cp(resolve(target, "Prover.toml.example"), resolve(target, "Prover.toml"));
  const homeDir = resolve(workRoot, "home");
  await mkdir(resolve(homeDir, "nargo"), { recursive: true });
  return {
    work_dir: workRoot,
    circuit_dir: target,
    home_dir: homeDir,
    keep_workdir,
  };
}

function shouldCopyCircuitPath(source, src) {
  const rel = relative(source, src);
  if (!rel) return true;
  const parts = rel.split(sep);
  if (parts.includes("target")) return false;
  const name = parts.at(-1);
  return ![
    "Prover.toml",
    "proof.bin",
    "proof.np",
    "public.json",
    DEFAULT_PROVEKIT_PROVER_KEY,
    DEFAULT_PROVEKIT_VERIFIER_KEY,
  ].includes(name);
}

function hex32(value) {
  if (typeof value !== "string") throw new FundraiseDemoRunnerError("bad_bytes32");
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) throw new FundraiseDemoRunnerError("bad_bytes32");
  return `0x${raw.toLowerCase()}`;
}

function evmAddress(value) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new FundraiseDemoRunnerError("bad_evm_address");
  }
  return value;
}

function defaultRepoRoot() {
  return resolve(dirname(fileURLToPath(import.meta.url)), "../..");
}
