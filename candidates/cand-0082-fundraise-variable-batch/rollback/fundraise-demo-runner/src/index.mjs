import { cp, mkdir, mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { basename, dirname, isAbsolute, relative, resolve, sep } from "node:path";
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
export const FUNDRAISE_DEMO_SUMMARY_SCHEMA = "aac.fundraise-demo-runner.summary.v1";
export const FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA = "aac.fundraise-demo-runner.local-settlement.v1";
export const DEFAULT_REGISTRY_PACKAGE = "registry";
export const DEFAULT_LOCAL_RPC_URL = "http://127.0.0.1:8545";
export const FUNDRAISE_DEMO_SERVER_SCHEMA = "aac.fundraise-demo-runner.server.v1";
export const DEFAULT_FUNDRAISE_DEMO_SERVER_HOST = "127.0.0.1";
export const DEFAULT_FUNDRAISE_DEMO_SERVER_PORT = 8787;
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
  const provekitBin = resolveFundraiseProveKitBin(input.provekit_bin, repoRoot);
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
        provekit_bin: provekitBin,
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
  const receipt = {
    ...buildDemoReceipt({
      input,
      packet: proof.packet,
      verifier_receipt: proof.verifier_receipt,
      workflow_receipt: workflowReceipt,
      workdir: proof.workdir,
    }),
    local_settlement: execution,
  };
  return { ...receipt, summary: buildFundraiseDemoSummary(receipt) };
}

export async function serveFundraiseDemo(input = {}) {
  const host = input.host ?? DEFAULT_FUNDRAISE_DEMO_SERVER_HOST;
  const port = Number(input.port ?? DEFAULT_FUNDRAISE_DEMO_SERVER_PORT);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new FundraiseDemoRunnerError("bad_server_port");
  }
  const baseInput = {
    repo_root: input.repo_root,
    provekit_bin: input.provekit_bin,
    keep_workdir: input.keep_workdir,
    timeout_ms: input.timeout_ms,
    env: input.env,
    run_command: input.run_command,
    workflow_policy: input.workflow_policy,
    recipient_overrides: input.recipient_overrides,
    verify_options: input.verify_options,
    registry_dir: input.registry_dir,
    rpc_url: input.rpc_url,
    forge_bin: input.forge_bin,
    cast_bin: input.cast_bin,
    solc_bin: input.solc_bin,
    deployer_private_key: input.deployer_private_key,
    authorizer_private_key: input.authorizer_private_key,
    token_name: input.token_name,
    token_symbol: input.token_symbol,
    foundry_command: input.foundry_command,
  };
  const staticDir = input.static_dir ? resolve(input.static_dir) : null;
  const server = createServer((request, response) => {
    handleFundraiseDemoRequest(request, response, {
      ...baseInput,
      settle_local: input.settle_local === true,
      cors_origin: input.cors_origin,
      static_dir: staticDir,
    }).catch((error) => {
      writeJson(response, 500, normalizeServerError(error), input.cors_origin);
    });
  });
  await new Promise((resolveListen, rejectListen) => {
    server.once("error", rejectListen);
    server.listen(port, host, () => {
      server.off("error", rejectListen);
      resolveListen();
    });
  });
  const address = server.address();
  const actualPort = typeof address === "object" && address ? address.port : port;
  return {
    schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
    host,
    port: actualPort,
    url: `http://${host}:${actualPort}`,
    server,
    close: () => new Promise((resolveClose, rejectClose) => {
      server.close((error) => (error ? rejectClose(error) : resolveClose()));
    }),
  };
}

export async function runFundraiseDemoServerAction(input = {}, request = {}) {
  const url = new URL(request.path ?? "/api/fundraise/run", "http://localhost");
  const body = request.body ?? {};
  const settleLocal = requestSettleLocal({ body, url, fallback: input.settle_local === true });
  const started = Date.now();
  const receipt = settleLocal
    ? await runFundraiseDemoLocalSettlement(input)
    : await runFundraiseDemo(input);
  return {
    schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
    accepted: true,
    reason: "accepted",
    mode: settleLocal ? "live-proof+local-settlement" : "live-proof",
    elapsed_ms: Date.now() - started,
    receipt,
    summary: receipt.summary,
  };
}

async function handleFundraiseDemoRequest(request, response, input) {
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
  if (request.method === "OPTIONS") {
    writeCorsPreflight(response, input.cors_origin);
    return;
  }
  if (request.method === "GET" && url.pathname === "/health") {
    writeJson(response, 200, {
      schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
      ok: true,
      service: "aac-fundraise-demo",
      live_proof: true,
      settle_local_default: input.settle_local === true,
    }, input.cors_origin);
    return;
  }
  if (["GET", "POST"].includes(request.method ?? "") && url.pathname === "/api/fundraise/run") {
    let body = {};
    if (request.method === "POST") {
      body = await readJsonRequest(request);
    }
    const payload = await runFundraiseDemoServerAction(input, { body, path: `${url.pathname}${url.search}` });
    writeJson(response, 200, payload, input.cors_origin);
    return;
  }
  if (["GET", "HEAD"].includes(request.method ?? "") && input.static_dir) {
    const served = await writeStaticAsset(response, input.static_dir, url.pathname, {
      cors_origin: input.cors_origin,
      omit_body: request.method === "HEAD",
    });
    if (served) return;
  }
  {
    writeJson(response, 404, {
      schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
      accepted: false,
      reason: "route_not_found",
    }, input.cors_origin);
    return;
  }
}

function requestSettleLocal({ body, url, fallback }) {
  if (typeof body.settle_local === "boolean") return body.settle_local;
  if (typeof body.settleLocal === "boolean") return body.settleLocal;
  const param = url.searchParams.get("settle_local") ?? url.searchParams.get("settleLocal");
  if (param === "1" || param === "true") return true;
  if (param === "0" || param === "false") return false;
  return fallback;
}

async function readJsonRequest(request) {
  let raw = "";
  for await (const chunk of request) {
    raw += chunk;
    if (raw.length > 64 * 1024) {
      throw new FundraiseDemoRunnerError("request_too_large");
    }
  }
  if (!raw.trim()) return {};
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("not_object");
    }
    return parsed;
  } catch (error) {
    throw new FundraiseDemoRunnerError("bad_json_request", "bad_json_request", {
      cause: error?.message ?? "parse_error",
    });
  }
}

function writeCorsPreflight(response, corsOrigin) {
  response.writeHead(204, corsHeaders(corsOrigin));
  response.end();
}

function writeJson(response, status, body, corsOrigin) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    ...corsHeaders(corsOrigin),
  });
  response.end(`${JSON.stringify(body, null, 2)}\n`);
}

async function writeStaticAsset(response, staticDir, pathname, options = {}) {
  const filePath = await resolveFundraiseStaticPath(staticDir, pathname);
  if (!filePath) return false;
  const body = await readFile(filePath);
  response.writeHead(200, {
    "content-type": fundraiseStaticContentType(filePath),
    "cache-control": filePath.endsWith("index.html") ? "no-store" : "public, max-age=31536000, immutable",
    ...corsHeaders(options.cors_origin),
  });
  response.end(options.omit_body ? undefined : body);
  return true;
}

export async function resolveFundraiseStaticPath(staticDir, pathname) {
  const root = resolve(staticDir);
  let decoded;
  try {
    decoded = decodeURIComponent(pathname || "/");
  } catch {
    return null;
  }
  const stripped = decoded.replace(/^\/+/, "");
  const candidate = resolve(root, stripped);
  if (!pathInside(root, candidate)) return null;
  const direct = await fileIfExists(candidate);
  if (direct) return direct;
  const indexed = await fileIfExists(resolve(candidate, "index.html"));
  if (indexed) return indexed;
  return null;
}

async function fileIfExists(candidate) {
  try {
    const info = await stat(candidate);
    if (info.isFile()) return candidate;
    if (info.isDirectory()) {
      const indexPath = resolve(candidate, "index.html");
      const indexInfo = await stat(indexPath);
      return indexInfo.isFile() ? indexPath : null;
    }
  } catch {
    return null;
  }
  return null;
}

function pathInside(root, candidate) {
  const rel = relative(root, candidate);
  return rel === "" || (!rel.startsWith("..") && !rel.startsWith(sep));
}

function resolveFundraiseProveKitBin(inputProveKitBin, repoRoot) {
  const provekitBin = inputProveKitBin ?? process.env.PROVEKIT_BIN;
  if (provekitBin === undefined || provekitBin === null) return undefined;
  if (typeof provekitBin !== "string" || provekitBin.length === 0) return provekitBin;
  if (isAbsolute(provekitBin) || !looksLikeExecutablePath(provekitBin)) return provekitBin;
  return resolve(repoRoot, provekitBin);
}

function looksLikeExecutablePath(value) {
  return value.startsWith(".") || value.includes("/") || value.includes("\\");
}

export function fundraiseStaticContentType(pathname) {
  if (pathname.endsWith(".html")) return "text/html; charset=utf-8";
  if (pathname.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (pathname.endsWith(".css")) return "text/css; charset=utf-8";
  if (pathname.endsWith(".json")) return "application/json; charset=utf-8";
  if (pathname.endsWith(".svg")) return "image/svg+xml";
  if (pathname.endsWith(".xml")) return "application/xml; charset=utf-8";
  if (pathname.endsWith(".txt")) return "text/plain; charset=utf-8";
  if (pathname.endsWith(".wasm")) return "application/wasm";
  if (pathname.endsWith(".png")) return "image/png";
  if (pathname.endsWith(".jpg") || pathname.endsWith(".jpeg")) return "image/jpeg";
  if (pathname.endsWith(".woff2")) return "font/woff2";
  return "application/octet-stream";
}

export function buildFundraiseDemoCorsHeaders(corsOrigin) {
  return {
    "access-control-allow-origin": corsOrigin || "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
    "access-control-allow-private-network": "true",
    "vary": "Origin, Access-Control-Request-Private-Network",
  };
}

function corsHeaders(corsOrigin) {
  return buildFundraiseDemoCorsHeaders(corsOrigin);
}

function normalizeServerError(error) {
  return {
    schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
    accepted: false,
    reason: error?.reason ?? "server_error",
    message: error?.message ?? "server_error",
    detail: error?.detail ?? {},
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
  const receipt = {
    schema: FUNDRAISE_DEMO_RUNNER_SCHEMA,
    accepted: true,
    reason: "accepted",
    vector_id: input.vector_id ?? DEFAULT_VECTOR_ID,
    packet_round_id: packet.public_inputs?.round_id ?? packet.round_policy?.round_id ?? null,
    packet_projection: buildFundraisePacketProjection(packet),
    public_inputs: packet.public_inputs ?? {},
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
  return { ...receipt, summary: buildFundraiseDemoSummary(receipt) };
}

function buildFundraisePacketProjection(packet) {
  const policy = packet.round_policy ?? {};
  return {
    round_policy: {
      round_id: policy.round_id ?? null,
      issuer_name: policy.issuer_name ?? null,
      settlement_asset_type_id: policy.settlement_asset_type_id ?? null,
      issued_unit_type_id: policy.issued_unit_type_id ?? null,
      price_numerator: finiteNumber(policy.price_numerator),
      price_denominator: finiteNumber(policy.price_denominator),
      max_issued_units: finiteNumber(policy.max_issued_units),
      max_settlement_amount: finiteNumber(policy.max_settlement_amount),
    },
    subscriptions: Array.isArray(packet.subscriptions)
      ? packet.subscriptions.map((sub) => ({
          subscription_id: sub.subscription_id ?? null,
          investor_id: sub.investor_id ?? null,
          settlement_ref: sub.settlement_ref ?? null,
          settlement_amount: finiteNumber(sub.settlement_amount),
          issued_units: finiteNumber(sub.issued_units),
          mint_recipient: sub.mint_recipient ?? null,
        }))
      : [],
  };
}

export function buildFundraiseDemoSummary(receipt) {
  if (!receipt || receipt.schema !== FUNDRAISE_DEMO_RUNNER_SCHEMA) {
    throw new FundraiseDemoRunnerError("receipt_schema_mismatch");
  }
  const publicInputs = receipt.public_inputs ?? {};
  const packetProjection = receipt.packet_projection ?? {};
  const policy = packetProjection.round_policy ?? {};
  const subscriptions = Array.isArray(packetProjection.subscriptions) ? packetProjection.subscriptions : [];
  const action = receipt.settlement_action ?? {};
  const auth = action.args?.auth ?? {};
  const verifier = receipt.verifier_receipt ?? {};
  const local = receipt.local_settlement ?? null;
  const settled = Boolean(local?.transaction_hash);
  const settlementAsset = settlementAssetLabel(policy.settlement_asset_type_id);
  const issuedUnit = issuedUnitLabel(policy.issued_unit_type_id);
  const unitNoun = issuedUnitNoun(policy.issued_unit_type_id);
  const subscriptionSettlementTotal = sumNumbers(subscriptions, "settlement_amount");
  const subscriptionIssuedTotal = sumNumbers(subscriptions, "issued_units");
  const settlementTotal = firstNumber(publicInputs.settlement_amount_total, subscriptionSettlementTotal);
  const issuedTotal = firstNumber(auth.issued_unit_total, publicInputs.issued_unit_total, subscriptionIssuedTotal);
  const recipientCount = Array.isArray(auth.recipients) ? auth.recipients.length : subscriptions.length;
  const pricePerUnit = priceFromPolicy(policy);
  const fills = subscriptions.map((sub, index) => ({
    party: sub.investor_id ?? `fill-${index + 1}`,
    subscription_id: sub.subscription_id ?? null,
    settlement_ref: sub.settlement_ref ?? null,
    settlement_amount: finiteNumber(sub.settlement_amount),
    settlement_label: amountWithUnit(sub.settlement_amount, settlementAsset),
    issued_units: finiteNumber(sub.issued_units),
    issued_label: amountWithUnit(sub.issued_units, unitNoun),
    recipient: sub.mint_recipient ?? null,
  }));
  const filledSettlement = sumNumbers(fills, "settlement_amount");
  const filledUnits = sumNumbers(fills, "issued_units");
  const openAfter = Math.max(0, (issuedTotal ?? 0) - filledUnits);
  const reconciliationAccepted =
    settlementTotal !== null
    && issuedTotal !== null
    && filledSettlement === settlementTotal
    && filledUnits === issuedTotal
    && openAfter === 0;
  return {
    schema: FUNDRAISE_DEMO_SUMMARY_SCHEMA,
    accepted: receipt.accepted === true,
    status: settled ? "settled-local" : "authorized-pending-signature",
    vector_id: receipt.vector_id,
    round_id: receipt.packet_round_id ?? publicInputs.round_id ?? null,
    issuer_name: publicInputs.issuer_name ?? null,
    metrics: [
      { value: amountValue(settlementTotal), label: `${settlementAsset} order size` },
      { value: amountValue(issuedTotal), label: issuedUnit },
      { value: amountValue(recipientCount), label: "fills in batch" },
    ],
    order: {
      headline: `Sell ${amountValue(issuedTotal)} ${issuedUnit}`,
      price_label: pricePerUnit === null ? "price unavailable" : `${amountValue(pricePerUnit)} ${settlementAsset} / ${singularUnit(unitNoun)}`,
      settlement_asset: settlementAsset,
      issued_unit: issuedUnit,
      issued_unit_noun: unitNoun,
      price_per_unit: pricePerUnit,
    },
    fills,
    opening_balances: [
      { label: `${settlementAsset} collected`, value: amountWithUnit(0, settlementAsset) },
      { label: `${unitNoun} issued`, value: amountWithUnit(0, unitNoun) },
      { label: `${unitNoun} open`, value: amountWithUnit(issuedTotal, unitNoun) },
    ],
    reconciliation: {
      accepted: reconciliationAccepted,
      rows: [
        {
          line: `${settlementAsset} collected`,
          opening: amountWithUnit(0, settlementAsset),
          delta: signedAmountWithUnit(filledSettlement, settlementAsset),
          closing: amountWithUnit(filledSettlement, settlementAsset),
        },
        {
          line: `${unitNoun} issued`,
          opening: amountWithUnit(0, unitNoun),
          delta: signedAmountWithUnit(filledUnits, unitNoun),
          closing: amountWithUnit(filledUnits, unitNoun),
        },
        {
          line: `${unitNoun} open`,
          opening: amountWithUnit(issuedTotal, unitNoun),
          delta: signedAmountWithUnit(-filledUnits, unitNoun),
          closing: amountWithUnit(openAfter, unitNoun),
        },
      ],
    },
    verifier: {
      accepted: verifier.accepted === true,
      status: verifier.accepted === true ? "accepted" : "not-run",
      status_label: verifier.accepted === true ? `${verifierModeLabel(verifier.mode)} accepted` : "verifier not run",
      target_label: verifierModeLabel(verifier.mode),
      verifier_id: verifier.verifier_id ?? null,
      verifier_profile: verifier.verifier_profile ?? null,
      proof_system: verifier.proof_system ?? receipt.provekit?.proof_system ?? null,
      mode: verifier.mode ?? receipt.provekit?.mode ?? null,
      packet_commitment: verifier.packet_commitment ?? null,
      public_inputs_commitment: verifier.public_inputs_commitment ?? null,
      proof_ref: verifier.proof_ref ?? receipt.provekit?.proof_ref ?? null,
      proof_digest: verifier.proof_digest ?? receipt.provekit?.proof_digest ?? null,
      verifier_key_digest: verifier.verifier_key_digest ?? receipt.provekit?.verifier_key_digest ?? null,
      receipt_digest: verifier.receipt_digest ?? receipt.workflow_receipt?.verifier_receipt_digest ?? null,
      adapter_schema: verifier.adapter_schema ?? null,
      timings_ms: verifier.timings_ms ?? receipt.provekit?.timings_ms ?? {},
      boundary: "Native ProveKit verification is live here; recursive/on-chain proof verification remains the production verifier target.",
    },
    economics: {
      settlement_amount_total: settlementTotal,
      issued_unit_total: issuedTotal,
      recipient_count: recipientCount,
    },
    commitments: {
      transition_set: publicInputs.transition_set_commitment ?? null,
      vnet_public: publicInputs.vnet_public_commitment ?? null,
      subscription_set: publicInputs.subscription_set_commitment ?? null,
      bcc_set: publicInputs.bcc_set_commitment ?? null,
      bridge_settlement: publicInputs.bridge_settlement_commitment ?? null,
      mint_recipient_set: auth.runtime_mint_recipient_set_commitment
        ?? publicInputs.mint_recipient_set_commitment
        ?? null,
      prev_balance_sheet_root: publicInputs.prev_balance_sheet_root ?? null,
      next_balance_sheet_root: publicInputs.next_balance_sheet_root ?? null,
      prev_cap_table_root: publicInputs.prev_cap_table_root ?? null,
      next_cap_table_root: publicInputs.next_cap_table_root ?? null,
    },
    proof: {
      mode: receipt.provekit?.mode ?? null,
      proof_system: receipt.provekit?.proof_system ?? null,
      proof_digest: receipt.provekit?.proof_digest ?? null,
      verifier_key_digest: receipt.provekit?.verifier_key_digest ?? null,
      timings_ms: receipt.provekit?.timings_ms ?? {},
    },
    workflow: {
      workflow_id: receipt.workflow_receipt?.workflow_id ?? null,
      workflow_engine: receipt.workflow_receipt?.workflow_engine ?? null,
      verifier_receipt_digest: receipt.workflow_receipt?.verifier_receipt_digest ?? null,
      authorizer_receipt_digest: receipt.workflow_receipt?.authorizer_receipt_digest ?? null,
      action_digest: action.action_digest ?? null,
      signature_status: settled ? "submitted" : action.signature_status ?? "pending",
    },
    settlement: {
      chain_id: action.chain_id ?? null,
      token_contract: local?.token_contract ?? auth.token_contract ?? null,
      settlement_contract: local?.settlement_contract ?? action.contract ?? null,
      authorizer: local?.authorizer ?? null,
      settlement_digest: local?.settlement_digest ?? null,
      transaction_hash: local?.transaction_hash ?? null,
      total_supply: local?.total_supply ?? null,
      balances: local?.balances ?? [],
    },
    claims: [
      "ProveKit accepted the VNET proof for the fundraise packet.",
      "The workflow authorized an EVM mint bound to the proof receipt and recipient set.",
      settled
        ? "A local settlement contract minted receipt tokens and refused replay."
        : "Settlement is pending an authorizer signature and transaction submission.",
    ],
    caveats: [
      "Local settlement uses deterministic development keys unless overridden.",
      "The current contract path verifies the authorizer signature and replay guard; production recursive/on-chain VNET proof verification remains a separate target.",
    ],
  };
}

function finiteNumber(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function firstNumber(...values) {
  for (const value of values) {
    const number = finiteNumber(value);
    if (number !== null) return number;
  }
  return null;
}

function sumNumbers(items, key) {
  return items.reduce((sum, item) => sum + (finiteNumber(item?.[key]) ?? 0), 0);
}

function settlementAssetLabel(typeId) {
  if (typeof typeId !== "string" || !typeId.trim()) return "settlement units";
  return typeId.split(":")[0] || "settlement units";
}

function issuedUnitLabel(typeId) {
  if (typeof typeId !== "string" || !typeId.trim()) return "receipt units";
  const family = typeId.split(":")[0]?.toUpperCase();
  if (family === "SAFE") return "restricted SAFE receipt units";
  return `${family || "restricted"} receipt units`;
}

function issuedUnitNoun(typeId) {
  if (typeof typeId !== "string" || !typeId.trim()) return "units";
  const tail = typeId.split(":").filter(Boolean).at(-1);
  if (!tail) return "units";
  if (tail.endsWith("s")) return tail;
  return `${tail}s`;
}

function singularUnit(unitNoun) {
  if (typeof unitNoun !== "string" || unitNoun.length === 0) return "unit";
  return unitNoun.endsWith("s") ? unitNoun.slice(0, -1) : unitNoun;
}

function priceFromPolicy(policy) {
  const numerator = finiteNumber(policy.price_numerator);
  const denominator = finiteNumber(policy.price_denominator);
  if (numerator === null || denominator === null || denominator === 0) return null;
  return numerator / denominator;
}

function amountValue(value) {
  const number = finiteNumber(value);
  if (number === null) return "n/a";
  if (Number.isInteger(number)) return String(number);
  return String(Number(number.toFixed(4)));
}

function amountWithUnit(value, unit) {
  return `${amountValue(value)} ${unit}`;
}

function signedAmountWithUnit(value, unit) {
  const number = finiteNumber(value) ?? 0;
  const sign = number >= 0 ? "+" : "";
  return `${sign}${amountValue(number)} ${unit}`;
}

function verifierModeLabel(mode) {
  if (mode === "native-cli") return "native ProveKit verifier";
  if (mode === "browser-wasm") return "browser ProveKit verifier";
  if (mode === "service") return "ProveKit verifier service";
  if (mode === "cre-workflow") return "CRE verifier workflow";
  return "ProveKit verifier";
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
