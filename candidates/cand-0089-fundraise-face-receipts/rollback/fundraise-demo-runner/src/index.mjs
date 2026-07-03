import { randomUUID } from "node:crypto";
import { cp, mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { basename, dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildProveKitVerifierReceipt,
  buildProveKitVerifierReceiptFromNativeCli,
  runProveKitNativeCli,
} from "../../fundraise-provekit-adapter/src/index.mjs";
import {
  buildFundraisePacket as buildRuntimeFundraisePacket,
  verifyFundraisePacket,
} from "../../fundraise-runtime/src/index.mjs";
import {
  authorizeFundraiseWorkflow,
  createWorkflowPolicy,
  packetCommitment,
  verifyWorkflowReceipt,
} from "../../fundraise-workflow/src/index.mjs";
import {
  certificateFor,
  commitVector,
  encodePoint,
  foldScalar,
  transitionReportFor,
} from "../../vnet-runtime/src/index.mjs";

export const FUNDRAISE_DEMO_RUNNER_SCHEMA = "aac.fundraise-demo-runner.receipt.v1";
export const DEFAULT_VECTOR_ID = "fundraise-demo-good";
export const DEFAULT_PROVEKIT_PACKAGE = "world-app/provekit-vnet";
export const DEFAULT_PROVEKIT_PROOF = "proof.np";
export const DEFAULT_PROVEKIT_PROVER_KEY = "aac_vnet_provekit.pkp";
export const DEFAULT_PROVEKIT_VERIFIER_KEY = "aac_vnet_provekit.pkv";
export const DEFAULT_BALANCE_SHEET_PROVEKIT_PACKAGE = "world-app/provekit-balance-sheet";
export const DEFAULT_BALANCE_SHEET_PROOF = "balance-sheet-proof.np";
export const DEFAULT_BALANCE_SHEET_PROVER_KEY = "aac_balance_sheet_provekit.pkp";
export const DEFAULT_BALANCE_SHEET_VERIFIER_KEY = "aac_balance_sheet_provekit.pkv";
export const FUNDRAISE_BALANCE_SHEET_PACKET_SCHEMA = "aac.fundraise-demo.balance-sheet-proof-packet.v1";
export const FUNDRAISE_DEMO_SUMMARY_SCHEMA = "aac.fundraise-demo-runner.summary.v1";
export const FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA = "aac.fundraise-demo-runner.local-settlement.v1";
export const FUNDRAISE_DEMO_PREVIEW_SCHEMA = "aac.fundraise-demo-runner.preview.v1";
export const DEFAULT_REGISTRY_PACKAGE = "registry";
export const DEFAULT_LOCAL_RPC_URL = "http://127.0.0.1:8545";
export const FUNDRAISE_DEMO_SERVER_SCHEMA = "aac.fundraise-demo-runner.server.v1";
export const FUNDRAISE_DEMO_PROOF_SESSION_SCHEMA = "aac.fundraise-demo-runner.proof-session.v1";
export const FUNDRAISE_DEMO_VERIFY_RESULT_SCHEMA = "aac.fundraise-demo-runner.verify-result.v1";
export const DEFAULT_FUNDRAISE_DEMO_SERVER_HOST = "127.0.0.1";
export const DEFAULT_FUNDRAISE_DEMO_SERVER_PORT = 8787;
export const DEFAULT_FUNDRAISE_PROOF_SESSION_TTL_MS = 10 * 60 * 1000;
export const DEFAULT_ANVIL_DEPLOYER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
export const DEFAULT_DEMO_AUTHORIZER_PRIVATE_KEY =
  "0x00000000000000000000000000000000000000000000000000000000000a11ce";

const BN254_FIELD_MODULUS =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const DEFAULT_BALANCE_SHEET_STATE_SALT = 424242n;
const BALANCE_SHEET_TAG = 8303001n;
const BALANCE_SHEET_CASH_COEFF = 1000003n;
const BALANCE_SHEET_ISSUED_COEFF = 1000033n;
const BALANCE_SHEET_OPEN_COEFF = 1000037n;
const BALANCE_SHEET_SALT_COEFF = 1000039n;
const fundraiseProofSessions = new Map();

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
    balance_sheet_packet: proof.balance_sheet_packet,
    balance_sheet_verifier_receipt: proof.balance_sheet_verifier_receipt,
    balance_sheet_state: proof.balance_sheet_state,
    workflow_receipt: workflowReceipt,
    workdir: proof.workdir,
    balance_sheet_workdir: proof.balance_sheet_workdir,
  });
}

export async function buildFundraiseDemoVerifierReceipt(input = {}) {
  const repoRoot = resolve(input.repo_root ?? defaultRepoRoot());
  const provekitBin = resolveFundraiseProveKitBin(input.provekit_bin, repoRoot);
  const sourcePacket = input.packet ?? (await loadFundraiseDemoPacket({
    repo_root: repoRoot,
    fixture_path: input.fixture_path,
    vector_id: input.vector_id,
  }));
  const packet = buildFundraiseDemoBatchPacket(sourcePacket, input);
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
    const balanceSheet = await buildBalanceSheetVerifierReceipt({
      input,
      packet,
      repo_root: repoRoot,
      provekit_bin: provekitBin,
    });
    return {
      packet,
      verifier_receipt: verifierReceipt,
      balance_sheet_packet: balanceSheet.packet,
      balance_sheet_verifier_receipt: balanceSheet.verifier_receipt,
      balance_sheet_state: balanceSheet.state,
      workdir: input.keep_workdir ? work.work_dir : null,
      balance_sheet_workdir: balanceSheet.workdir,
      provekit_artifacts: {
        provekit_bin: provekitBin,
        circuit_dir: work.circuit_dir,
        home_dir: work.home_dir,
        public_inputs: packet.public_inputs,
        prover_toml: "Prover.toml",
        prover_key: input.prover_key ?? DEFAULT_PROVEKIT_PROVER_KEY,
        verifier_key: input.verifier_key ?? DEFAULT_PROVEKIT_VERIFIER_KEY,
        proof: input.proof ?? DEFAULT_PROVEKIT_PROOF,
        proof_ref: input.proof_ref,
        verifier_id: input.verifier_id ?? "aac-fundraise-demo-provekit",
        verifier_profile: "fundraise-runtime/v1+vnet-runtime/v1",
      },
      balance_sheet_provekit_artifacts: balanceSheet.provekit_artifacts,
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
      balance_sheet_packet: proof.balance_sheet_packet,
      balance_sheet_verifier_receipt: proof.balance_sheet_verifier_receipt,
      balance_sheet_state: proof.balance_sheet_state,
      workdir: proof.workdir,
      balance_sheet_workdir: proof.balance_sheet_workdir,
    }),
    local_settlement: execution,
  };
  return { ...receipt, summary: buildFundraiseDemoSummary(receipt) };
}

export async function previewFundraiseDemo(input = {}) {
  const started = Date.now();
  const repoRoot = resolve(input.repo_root ?? defaultRepoRoot());
  const sourcePacket = input.packet ?? (await loadFundraiseDemoPacket({
    repo_root: repoRoot,
    fixture_path: input.fixture_path,
    vector_id: input.vector_id,
  }));
  const packet = buildFundraiseDemoBatchPacket(sourcePacket, input);
  const receipt = buildPreviewReceipt({ input, packet });
  return {
    schema: FUNDRAISE_DEMO_PREVIEW_SCHEMA,
    accepted: true,
    reason: "accepted",
    mode: "preview",
    elapsed_ms: Date.now() - started,
    receipt,
    summary: receipt.summary,
  };
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
  const variableFillUnits = requestVariableFillUnits({ body, url });
  const actionInput = variableFillUnits === undefined
    ? input
    : { ...input, variable_fill_units: variableFillUnits };
  const started = Date.now();
  const receipt = settleLocal
    ? await runFundraiseDemoLocalSettlement(actionInput)
    : await runFundraiseDemo(actionInput);
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

export async function runFundraiseDemoProveAction(input = {}, request = {}) {
  const url = new URL(request.path ?? "/api/fundraise/prove", "http://localhost");
  const body = request.body ?? {};
  const variableFillUnits = requestVariableFillUnits({ body, url });
  const actionInput = {
    ...input,
    ...(variableFillUnits === undefined ? {} : { variable_fill_units: variableFillUnits }),
    keep_workdir: true,
  };
  const started = Date.now();
  const proof = await buildFundraiseDemoVerifierReceipt(actionInput);
  const workflowReceipt = buildLiveWorkflowReceipt({
    packet: proof.packet,
    verifier_receipt: proof.verifier_receipt,
    workflow_policy: actionInput.workflow_policy,
    recipient_overrides: actionInput.recipient_overrides,
    verify_options: actionInput.verify_options,
  });
  const receipt = buildDemoReceipt({
    input: actionInput,
    packet: proof.packet,
    verifier_receipt: proof.verifier_receipt,
    balance_sheet_packet: proof.balance_sheet_packet,
    balance_sheet_verifier_receipt: proof.balance_sheet_verifier_receipt,
    balance_sheet_state: proof.balance_sheet_state,
    workflow_receipt: workflowReceipt,
    workdir: proof.workdir,
    balance_sheet_workdir: proof.balance_sheet_workdir,
  });
  const session = storeFundraiseProofSession({ input: actionInput, proof, receipt });
  return {
    schema: FUNDRAISE_DEMO_SERVER_SCHEMA,
    accepted: true,
    reason: "accepted",
    mode: "proof-generated",
    elapsed_ms: Date.now() - started,
    proof_id: session.proof_id,
    proof_session: publicFundraiseProofSession(session),
    receipt,
    summary: receipt.summary,
  };
}

export async function runFundraiseDemoVerifyAction(input = {}, request = {}) {
  const started = Date.now();
  pruneFundraiseProofSessions();
  const body = request.body ?? {};
  const proofId = stringField(body.proof_id).trim();
  const session = fundraiseProofSessions.get(proofId);
  if (!session) {
    return fundraiseVerifyRejection({
      reason: "proof_session_missing",
      proof_id: proofId,
      elapsed_ms: Date.now() - started,
    });
  }
  if (session.expires_at_ms <= Date.now()) {
    fundraiseProofSessions.delete(session.proof_id);
    cleanupFundraiseProofSession(session);
    return fundraiseVerifyRejection({
      reason: "proof_session_expired",
      proof_id: proofId,
      elapsed_ms: Date.now() - started,
    });
  }
  const mismatches = submittedVerifyFieldMismatches(body, session.expected_fields);
  if (mismatches.length > 0) {
    return fundraiseVerifyRejection({
      reason: "submitted_public_input_mismatch",
      proof_id: proofId,
      elapsed_ms: Date.now() - started,
      detail: { mismatches },
    });
  }
  const verifierReceipt = await rerunStoredFundraiseVerification(session, "vnet");
  const balanceSheetVerifierReceipt = await rerunStoredFundraiseVerification(session, "balance_sheet");
  const receipt = {
    ...session.receipt,
    verifier_receipt: verifierReceipt,
    balance_sheet_verifier_receipt: balanceSheetVerifierReceipt,
    provekit: {
      ...session.receipt.provekit,
      proof_digest: verifierReceipt.proof_digest,
      verifier_key_digest: verifierReceipt.verifier_key_digest,
      timings_ms: {
        ...(session.receipt.provekit?.timings_ms ?? {}),
        verify: verifierReceipt.timings_ms.verify,
      },
    },
    balance_sheet_provekit: {
      ...(session.receipt.balance_sheet_provekit ?? {}),
      proof_digest: balanceSheetVerifierReceipt.proof_digest,
      verifier_key_digest: balanceSheetVerifierReceipt.verifier_key_digest,
      timings_ms: {
        ...(session.receipt.balance_sheet_provekit?.timings_ms ?? {}),
        verify: balanceSheetVerifierReceipt.timings_ms.verify,
      },
    },
  };
  const summary = buildFundraiseDemoSummary(receipt);
  const verifiedReceipt = { ...receipt, summary };
  session.receipt = verifiedReceipt;
  return {
    schema: FUNDRAISE_DEMO_VERIFY_RESULT_SCHEMA,
    accepted: true,
    reason: "accepted",
    mode: "form-verify",
    proof_id: proofId,
    elapsed_ms: Date.now() - started,
    proof_session: publicFundraiseProofSession(session),
    receipt: verifiedReceipt,
    summary,
    verification: {
      status: "accepted",
      fields: session.expected_fields,
    },
  };
}

function storeFundraiseProofSession({ input, proof, receipt }) {
  pruneFundraiseProofSessions();
  const now = Date.now();
  const ttl = finitePositiveNumber(input.proof_session_ttl_ms, DEFAULT_FUNDRAISE_PROOF_SESSION_TTL_MS);
  const proofId = `proof_${randomUUID().replaceAll("-", "")}`;
  const session = {
    schema: FUNDRAISE_DEMO_PROOF_SESSION_SCHEMA,
    proof_id: proofId,
    created_at_ms: now,
    expires_at_ms: now + ttl,
    receipt,
    expected_fields: buildFundraiseVerifyFields(proofId, receipt.summary),
    timeout_ms: input.timeout_ms,
    env: input.env,
    run_command: input.run_command,
    cleanup_paths: Array.from(new Set([proof.workdir, proof.balance_sheet_workdir].filter(Boolean))),
    artifacts: {
      vnet: {
        ...(proof.provekit_artifacts ?? {}),
        packet: proof.packet,
      },
      balance_sheet: {
        ...(proof.balance_sheet_provekit_artifacts ?? {}),
        packet: proof.balance_sheet_packet,
      },
    },
  };
  fundraiseProofSessions.set(proofId, session);
  return session;
}

function publicFundraiseProofSession(session) {
  return {
    schema: FUNDRAISE_DEMO_PROOF_SESSION_SCHEMA,
    proof_id: session.proof_id,
    expires_at: new Date(session.expires_at_ms).toISOString(),
    verify_fields: session.expected_fields,
  };
}

function buildFundraiseVerifyFields(proofId, summary) {
  const verifier = summary.verifier ?? {};
  const balanceSheet = summary.balance_sheet ?? {};
  const roots = balanceSheet.roots ?? {};
  const publicInputs = balanceSheet.public_inputs ?? {};
  return {
    proof_id: proofId,
    packet_commitment: stringField(verifier.packet_commitment),
    public_inputs_commitment: stringField(verifier.public_inputs_commitment),
    proof_digest: stringField(verifier.proof_digest),
    verifier_key_digest: stringField(verifier.verifier_key_digest),
    balance_packet_commitment: stringField(balanceSheet.packet_commitment),
    balance_public_inputs_commitment: stringField(balanceSheet.public_inputs_commitment),
    balance_proof_digest: stringField(balanceSheet.proof_digest),
    balance_verifier_key_digest: stringField(balanceSheet.verifier_key_digest),
    balance_prev_balance_sheet_root: stringField(roots.prev_balance_sheet_root),
    balance_next_balance_sheet_root: stringField(roots.next_balance_sheet_root),
    balance_issued_unit_total: stringField(publicInputs.issued_unit_total ?? summary.economics?.issued_unit_total),
    balance_fundraise_packet_commitment: stringField(balanceSheet.fundraise_packet_commitment),
  };
}

function submittedVerifyFieldMismatches(body, expected) {
  const mismatches = [];
  for (const [field, expectedValue] of Object.entries(expected)) {
    const submitted = stringField(body[field]);
    if (submitted !== expectedValue) {
      mismatches.push({ field, expected: expectedValue, submitted });
    }
  }
  return mismatches;
}

async function rerunStoredFundraiseVerification(session, kind) {
  const artifact = session.artifacts[kind];
  if (!artifact?.packet || !artifact.circuit_dir) {
    throw new FundraiseDemoRunnerError("proof_session_artifact_missing", kind);
  }
  const provekit = await runProveKitNativeCli({
    public_inputs: artifact.public_inputs,
    provekit_bin: artifact.provekit_bin,
    circuit_dir: artifact.circuit_dir,
    cwd: artifact.circuit_dir,
    prover_toml: artifact.prover_toml ?? "Prover.toml",
    prover_key: artifact.prover_key,
    verifier_key: artifact.verifier_key,
    proof: artifact.proof,
    proof_ref: artifact.proof_ref,
    timeout_ms: session.timeout_ms ?? 300_000,
    env: { HOME: artifact.home_dir, ...(session.env ?? {}) },
    run_command: session.run_command,
    prepare: false,
    prove: false,
    verify: true,
  });
  return buildProveKitVerifierReceipt({
    packet: artifact.packet,
    provekit,
    verifier_id: artifact.verifier_id,
    verifier_profile: artifact.verifier_profile,
  });
}

function fundraiseVerifyRejection({ reason, proof_id, elapsed_ms, detail = {} }) {
  return {
    schema: FUNDRAISE_DEMO_VERIFY_RESULT_SCHEMA,
    accepted: false,
    reason,
    mode: "form-verify",
    proof_id: proof_id || null,
    elapsed_ms,
    detail,
  };
}

function pruneFundraiseProofSessions(now = Date.now()) {
  for (const session of fundraiseProofSessions.values()) {
    if (session.expires_at_ms <= now) {
      fundraiseProofSessions.delete(session.proof_id);
      cleanupFundraiseProofSession(session);
    }
  }
}

function cleanupFundraiseProofSession(session) {
  for (const path of session.cleanup_paths ?? []) {
    void rm(path, { recursive: true, force: true }).catch(() => {});
  }
}

function finitePositiveNumber(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : fallback;
}

function stringField(value) {
  if (value === undefined || value === null) return "";
  if (Array.isArray(value)) return value.map((item) => stringField(item)).join(",");
  return String(value);
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
      form_verify: true,
      settle_local_default: input.settle_local === true,
    }, input.cors_origin);
    return;
  }
  if (["GET", "POST"].includes(request.method ?? "") && url.pathname === "/api/fundraise/prove") {
    let body = {};
    if (request.method === "POST") {
      body = await readRequestPayload(request);
    }
    const payload = await runFundraiseDemoProveAction(input, { body, path: `${url.pathname}${url.search}` });
    writeJson(response, 200, payload, input.cors_origin);
    return;
  }
  if (["GET", "POST"].includes(request.method ?? "") && url.pathname === "/api/fundraise/verify") {
    const body = request.method === "POST"
      ? await readRequestPayload(request)
      : Object.fromEntries(url.searchParams.entries());
    const payload = await runFundraiseDemoVerifyAction(input, { body, path: `${url.pathname}${url.search}` });
    if (requestWantsHtmlFragment(request)) {
      writeHtml(response, 200, fundraiseVerifyResultHtml(payload), input.cors_origin);
    } else {
      writeJson(response, 200, payload, input.cors_origin);
    }
    return;
  }
  if (["GET", "POST"].includes(request.method ?? "") && url.pathname === "/api/fundraise/run") {
    let body = {};
    if (request.method === "POST") {
      body = await readRequestPayload(request);
    }
    const payload = await runFundraiseDemoServerAction(input, { body, path: `${url.pathname}${url.search}` });
    writeJson(response, 200, payload, input.cors_origin);
    return;
  }
  if (["GET", "POST"].includes(request.method ?? "") && url.pathname === "/api/fundraise/preview") {
    let body = {};
    if (request.method === "POST") {
      body = await readRequestPayload(request);
    }
    const urlInput = new URL(`${url.pathname}${url.search}`, "http://localhost");
    const variableFillUnits = requestVariableFillUnits({ body, url: urlInput });
    const payload = await previewFundraiseDemo(
      variableFillUnits === undefined ? input : { ...input, variable_fill_units: variableFillUnits },
    );
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

function requestVariableFillUnits({ body, url }) {
  const bodyValue = body.variable_fill_units
    ?? body.variableFillUnits
    ?? body.batch_units
    ?? body.batchUnits;
  const param = bodyValue
    ?? url.searchParams.get("variable_fill_units")
    ?? url.searchParams.get("variableFillUnits")
    ?? url.searchParams.get("batch_units")
    ?? url.searchParams.get("batchUnits");
  if (param === undefined || param === null || param === "") return undefined;
  const value = typeof param === "number" ? param : Number(param);
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new FundraiseDemoRunnerError("bad_variable_fill_units");
  }
  return value;
}

async function readRequestPayload(request) {
  let raw = "";
  for await (const chunk of request) {
    raw += chunk;
    if (raw.length > 64 * 1024) {
      throw new FundraiseDemoRunnerError("request_too_large");
    }
  }
  if (!raw.trim()) return {};
  const contentType = String(request.headers["content-type"] ?? "");
  if (contentType.includes("application/x-www-form-urlencoded")) {
    return Object.fromEntries(new URLSearchParams(raw).entries());
  }
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

function writeHtml(response, status, body, corsOrigin) {
  response.writeHead(status, {
    "content-type": "text/html; charset=utf-8",
    "cache-control": "no-store",
    ...corsHeaders(corsOrigin),
  });
  response.end(body);
}

function requestWantsHtmlFragment(request) {
  if (String(request.headers["hx-request"] ?? "").toLowerCase() === "true") return true;
  const accept = String(request.headers.accept ?? "");
  return accept.includes("text/html") && !accept.includes("application/json");
}

function fundraiseVerifyResultHtml(payload) {
  const accepted = payload.accepted === true;
  const status = accepted ? "accepted" : "rejected";
  const title = accepted ? "Verifier accepted submitted inputs" : "Verifier rejected submitted inputs";
  const detail = accepted
    ? "Native ProveKit verify reran for the order-fill proof and the balance-sheet proof."
    : verifyRejectionDetail(payload);
  const proofId = payload.proof_id ? `proof ${payload.proof_id}` : "proof session unavailable";
  return [
    `<div class="verify-result ${status}" data-verify-accepted="${accepted ? "true" : "false"}" data-verify-reason="${escapeHtml(payload.reason ?? status)}">`,
    `<strong>${escapeHtml(title)}</strong>`,
    `<span>${escapeHtml(detail)}</span>`,
    `<code>${escapeHtml(proofId)} · ${escapeHtml(String(payload.elapsed_ms ?? 0))}ms</code>`,
    `</div>`,
  ].join("");
}

function verifyRejectionDetail(payload) {
  const mismatches = payload.detail?.mismatches;
  if (Array.isArray(mismatches) && mismatches.length > 0) {
    return `field mismatch: ${mismatches.map((item) => item.field).join(", ")}`;
  }
  if (payload.reason === "proof_session_missing") return "Generate a proof packet before submitting verifier inputs.";
  if (payload.reason === "proof_session_expired") return "The proof session expired; generate a fresh proof packet.";
  return payload.reason ?? "verification failed";
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[char]);
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
    "access-control-allow-headers": "content-type,hx-request",
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

async function buildBalanceSheetVerifierReceipt({ input, packet, repo_root, provekit_bin }) {
  const proofInput = buildBalanceSheetProofInput(packet, input);
  const balancePacket = buildBalanceSheetProofPacket(packet, proofInput);
  const work = await prepareProveKitWorkdir({
    repo_root,
    circuit_dir: input.balance_sheet_circuit_dir ?? DEFAULT_BALANCE_SHEET_PROVEKIT_PACKAGE,
    work_dir: input.balance_sheet_work_dir,
    keep_workdir: input.keep_workdir,
  });
  try {
    await writeFile(resolve(work.circuit_dir, "Prover.toml"), buildBalanceSheetProverToml(proofInput));
    const provekit = await runProveKitNativeCli({
      public_inputs: balancePacket.public_inputs,
      provekit_bin,
      circuit_dir: work.circuit_dir,
      cwd: work.circuit_dir,
      prover_toml: "Prover.toml",
      prover_key: input.balance_sheet_prover_key ?? DEFAULT_BALANCE_SHEET_PROVER_KEY,
      verifier_key: input.balance_sheet_verifier_key ?? DEFAULT_BALANCE_SHEET_VERIFIER_KEY,
      proof: input.balance_sheet_proof ?? DEFAULT_BALANCE_SHEET_PROOF,
      proof_ref: input.balance_sheet_proof_ref,
      timeout_ms: input.timeout_ms ?? 300_000,
      env: { HOME: work.home_dir, ...(input.env ?? {}) },
      run_command: input.run_command,
    });
    const verifierReceipt = buildProveKitVerifierReceipt({
      packet: balancePacket,
      provekit,
      verifier_id: input.balance_sheet_verifier_id ?? "aac-fundraise-balance-sheet-provekit",
      verifier_profile: input.balance_sheet_verifier_profile ?? "fundraise-balance-sheet-demo/v1",
    });
    return {
      packet: balancePacket,
      verifier_receipt: verifierReceipt,
      state: publicBalanceSheetState(proofInput),
      workdir: input.keep_workdir ? work.work_dir : null,
      provekit_artifacts: {
        provekit_bin,
        circuit_dir: work.circuit_dir,
        home_dir: work.home_dir,
        public_inputs: balancePacket.public_inputs,
        prover_toml: "Prover.toml",
        prover_key: input.balance_sheet_prover_key ?? DEFAULT_BALANCE_SHEET_PROVER_KEY,
        verifier_key: input.balance_sheet_verifier_key ?? DEFAULT_BALANCE_SHEET_VERIFIER_KEY,
        proof: input.balance_sheet_proof ?? DEFAULT_BALANCE_SHEET_PROOF,
        proof_ref: input.balance_sheet_proof_ref,
        verifier_id: input.balance_sheet_verifier_id ?? "aac-fundraise-balance-sheet-provekit",
        verifier_profile: input.balance_sheet_verifier_profile ?? "fundraise-balance-sheet-demo/v1",
      },
    };
  } finally {
    if (!input.keep_workdir) {
      await rm(work.work_dir, { recursive: true, force: true });
    }
  }
}

function buildDemoReceipt({
  input,
  packet,
  verifier_receipt,
  balance_sheet_packet,
  balance_sheet_verifier_receipt,
  balance_sheet_state,
  workflow_receipt,
  workdir,
  balance_sheet_workdir,
}) {
  const balanceSheetProvekit = balance_sheet_verifier_receipt
    ? {
        mode: balance_sheet_verifier_receipt.mode,
        proof_system: balance_sheet_verifier_receipt.proof_system,
        proof_ref: balance_sheet_verifier_receipt.proof_ref,
        proof_digest: balance_sheet_verifier_receipt.proof_digest,
        verifier_key_digest: balance_sheet_verifier_receipt.verifier_key_digest,
        timings_ms: balance_sheet_verifier_receipt.timings_ms,
      }
    : {
        mode: null,
        proof_system: null,
        proof_ref: null,
        proof_digest: null,
        verifier_key_digest: null,
        timings_ms: {},
      };
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
    balance_sheet_packet,
    balance_sheet_verifier_receipt,
    balance_sheet_state,
    balance_sheet_provekit: balanceSheetProvekit,
    workflow_receipt,
    settlement_action: workflow_receipt.settlement_action,
    workdir,
    balance_sheet_workdir,
  };
  return { ...receipt, summary: buildFundraiseDemoSummary(receipt) };
}

function buildPreviewReceipt({ input, packet }) {
  const proofInput = buildBalanceSheetProofInput(packet, input);
  const balanceSheetPacket = buildBalanceSheetProofPacket(packet, proofInput);
  const receipt = {
    schema: FUNDRAISE_DEMO_RUNNER_SCHEMA,
    accepted: false,
    reason: "ready",
    vector_id: input.vector_id ?? DEFAULT_VECTOR_ID,
    packet_round_id: packet.public_inputs?.round_id ?? packet.round_policy?.round_id ?? null,
    packet_projection: buildFundraisePacketProjection(packet),
    public_inputs: packet.public_inputs ?? {},
    provekit: {
      mode: null,
      proof_system: null,
      proof_ref: null,
      proof_digest: null,
      verifier_key_digest: null,
      timings_ms: {},
    },
    verifier_receipt: {},
    balance_sheet_packet: balanceSheetPacket,
    balance_sheet_verifier_receipt: {},
    balance_sheet_state: publicBalanceSheetState(proofInput),
    balance_sheet_provekit: {
      mode: null,
      proof_system: null,
      proof_ref: null,
      proof_digest: null,
      verifier_key_digest: null,
      timings_ms: {},
    },
    workflow_receipt: null,
    settlement_action: {},
    workdir: null,
    balance_sheet_workdir: null,
  };
  return { ...receipt, summary: buildFundraiseDemoSummary(receipt) };
}

export function buildFundraiseDemoBatchPacket(packet, input = {}) {
  const source = cloneJson(packet);
  const subscriptions = Array.isArray(source.subscriptions) ? source.subscriptions.map((sub) => ({ ...sub })) : [];
  if (subscriptions.length < 2) {
    throw new FundraiseDemoRunnerError("variable_fill_missing");
  }
  const policy = { ...(source.round_policy ?? {}) };
  const fixedSub = subscriptions[0];
  const variableSub = subscriptions[1];
  const fixedUnits = safeInt(fixedSub.issued_units, "bad_fixed_fill_units");
  const defaultVariableUnits = safeInt(variableSub.issued_units, "bad_variable_fill_units");
  const variableUnits = normalizeVariableFillUnits(input.variable_fill_units ?? input.variableFillUnits ?? input.batch_units ?? input.batchUnits)
    ?? defaultVariableUnits;
  const originalTotalUnits = safeInt(
    source.public_inputs?.issued_unit_total ?? subscriptions.reduce((sum, sub) => sum + safeInt(sub.issued_units, "bad_issued_units"), 0),
    "bad_order_units",
  );
  const maxVariableUnits = Math.max(0, originalTotalUnits - fixedUnits);
  if (variableUnits > maxVariableUnits) {
    throw new FundraiseDemoRunnerError("variable_fill_cap_exceeded", "variable_fill_cap_exceeded", {
      fixed_units: fixedUnits,
      variable_units: variableUnits,
      max_variable_units: maxVariableUnits,
      order_units: originalTotalUnits,
    });
  }
  const settlementAmount = settlementForUnits(policy, variableUnits);
  variableSub.issued_units = variableUnits;
  variableSub.settlement_amount = settlementAmount;
  policy.max_issued_units = originalTotalUnits;
  policy.max_settlement_amount = settlementForUnits(policy, originalTotalUnits);
  const vnetLink = rebuildFundraiseVnetLink(source.vnet_link, policy, subscriptions);
  const rebuilt = buildRuntimeFundraisePacket({
    policy,
    subscriptions,
    vnetLink,
  });
  const verified = verifyFundraisePacket(rebuilt);
  if (!verified.accepted) {
    throw new FundraiseDemoRunnerError("variable_batch_packet_rejected", verified.reason, {
      verifier_reason: verified.reason,
    });
  }
  return attachFundraiseBalanceSheetRoots(rebuilt, input);
}

export function attachFundraiseBalanceSheetRoots(packet, input = {}) {
  const next = cloneJson(packet);
  const roots = buildBalanceSheetRootState(next, input);
  next.public_inputs.prev_balance_sheet_root = roots.public_inputs.prev_balance_sheet_root;
  next.public_inputs.next_balance_sheet_root = roots.public_inputs.next_balance_sheet_root;
  return next;
}

export function buildBalanceSheetProofPacket(packet, proofInput = buildBalanceSheetProofInput(packet)) {
  const commitment = packetCommitment(packet);
  return {
    schema: FUNDRAISE_BALANCE_SHEET_PACKET_SCHEMA,
    profile_id: "fundraise-balance-sheet-demo/v1",
    commitment_profile: "aac.demo.balance-sheet-linear-commitment/1",
    round_id: packet.public_inputs?.round_id ?? packet.round_policy?.round_id ?? null,
    issuer_name: packet.public_inputs?.issuer_name ?? packet.round_policy?.issuer_name ?? null,
    fundraise_packet_commitment: commitment,
    public_inputs: proofInput.public_inputs,
    roots: proofInput.roots,
    rows: proofInput.rows,
    boundary:
      "Proves private before/after state arithmetic for the selected batch; starting balance-sheet truth still needs an external anchor.",
  };
}

export function buildBalanceSheetProofInput(packet, input = {}) {
  const rootState = buildBalanceSheetRootState(packet, input);
  const commitmentField = fieldString(fieldFromHexDigest(packetCommitment(packet)));
  return {
    ...rootState,
    public_inputs: {
      ...rootState.public_inputs,
      fundraise_packet_commitment: commitmentField,
    },
    witness: {
      opening_cash_collected: fieldString(rootState.opening.cash_collected),
      opening_units_issued: fieldString(rootState.opening.units_issued),
      opening_units_open: fieldString(rootState.opening.units_open),
      state_salt: fieldString(rootState.salt),
      expected_fundraise_packet_commitment: commitmentField,
    },
  };
}

function buildBalanceSheetRootState(packet, input = {}) {
  const pub = packet.public_inputs ?? {};
  const policy = packet.round_policy ?? {};
  const settlementTotal = safeInt(pub.settlement_amount_total, "bad_balance_sheet_settlement_total");
  const issuedTotal = safeInt(pub.issued_unit_total, "bad_balance_sheet_issued_total");
  const orderCap = safeInt(policy.max_issued_units, "bad_balance_sheet_order_cap");
  if (issuedTotal > orderCap) {
    throw new FundraiseDemoRunnerError("balance_sheet_overfill");
  }
  const salt = normalizeField(input.balance_sheet_salt ?? DEFAULT_BALANCE_SHEET_STATE_SALT, "bad_balance_sheet_salt");
  const opening = {
    cash_collected: 0n,
    units_issued: 0n,
    units_open: BigInt(orderCap),
  };
  const delta = {
    cash_collected: BigInt(settlementTotal),
    units_issued: BigInt(issuedTotal),
    units_open: -BigInt(issuedTotal),
  };
  const closing = {
    cash_collected: opening.cash_collected + delta.cash_collected,
    units_issued: opening.units_issued + delta.units_issued,
    units_open: opening.units_open + delta.units_open,
  };
  const prevRoot = balanceSheetRoot(opening, salt);
  const nextRoot = balanceSheetRoot(closing, salt);
  return {
    salt,
    opening,
    delta,
    closing,
    roots: {
      prev_balance_sheet_root: fieldString(prevRoot),
      next_balance_sheet_root: fieldString(nextRoot),
    },
    public_inputs: {
      prev_balance_sheet_root: fieldString(prevRoot),
      next_balance_sheet_root: fieldString(nextRoot),
      settlement_amount_total: fieldString(settlementTotal),
      issued_unit_total: fieldString(issuedTotal),
      order_cap_units: fieldString(orderCap),
    },
    rows: [
      {
        line: "cash_collected",
        opening: numberFromBigInt(opening.cash_collected),
        delta: numberFromBigInt(delta.cash_collected),
        closing: numberFromBigInt(closing.cash_collected),
      },
      {
        line: "units_issued",
        opening: numberFromBigInt(opening.units_issued),
        delta: numberFromBigInt(delta.units_issued),
        closing: numberFromBigInt(closing.units_issued),
      },
      {
        line: "units_open",
        opening: numberFromBigInt(opening.units_open),
        delta: numberFromBigInt(delta.units_open),
        closing: numberFromBigInt(closing.units_open),
      },
    ],
  };
}

function publicBalanceSheetState(proofInput) {
  return {
    commitment_profile: "aac.demo.balance-sheet-linear-commitment/1",
    roots: proofInput.roots,
    public_inputs: proofInput.public_inputs,
    rows: proofInput.rows,
  };
}

function buildBalanceSheetProverToml(proofInput) {
  const values = {
    ...proofInput.public_inputs,
    ...proofInput.witness,
  };
  return `${Object.entries(values)
    .map(([key, value]) => `${key} = "${value}"`)
    .join("\n")}\n`;
}

function balanceSheetRoot(row, salt) {
  return (
    BALANCE_SHEET_TAG
    + row.cash_collected * BALANCE_SHEET_CASH_COEFF
    + row.units_issued * BALANCE_SHEET_ISSUED_COEFF
    + row.units_open * BALANCE_SHEET_OPEN_COEFF
    + salt * BALANCE_SHEET_SALT_COEFF
  ) % BN254_FIELD_MODULUS;
}

function fieldFromHexDigest(value) {
  if (typeof value !== "string") throw new FundraiseDemoRunnerError("bad_hex_digest");
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]+$/.test(raw)) throw new FundraiseDemoRunnerError("bad_hex_digest");
  return BigInt(`0x${raw}`) % BN254_FIELD_MODULUS;
}

function normalizeField(value, reason) {
  try {
    if (typeof value === "bigint") return value;
    if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) return BigInt(value);
    if (typeof value === "string" && /^[0-9]+$/.test(value)) return BigInt(value);
  } catch {
    // fall through to the typed error below
  }
  throw new FundraiseDemoRunnerError(reason);
}

function fieldString(value) {
  return typeof value === "bigint" ? value.toString(10) : String(value);
}

function numberFromBigInt(value) {
  if (value > BigInt(Number.MAX_SAFE_INTEGER) || value < BigInt(Number.MIN_SAFE_INTEGER)) {
    throw new FundraiseDemoRunnerError("balance_sheet_number_overflow");
  }
  return Number(value);
}

function rebuildFundraiseVnetLink(vnetLink, policy, subscriptions) {
  const link = cloneJson(vnetLink);
  const atoms = link?.vnet?.atoms;
  if (!Array.isArray(atoms) || atoms.length < subscriptions.length * 2) {
    throw new FundraiseDemoRunnerError("vnet_atoms_missing");
  }
  for (const [index, sub] of subscriptions.entries()) {
    const settlement = safeInt(sub.settlement_amount, "bad_settlement_amount");
    const issued = safeInt(sub.issued_units, "bad_issued_units");
    updateVnetAtom(atoms[index * 2], [0, issued], [settlement, 0]);
    updateVnetAtom(atoms[index * 2 + 1], [settlement, 0], [0, issued]);
  }
  link.vnet.transition_set_commitment = foldScalar(
    "aac/vnet-bn254-g1/1/transition-set",
    atoms.map((atom) => [atom.transition_ref, atom.journal_commitment]),
  );
  link.vnet.commitment_set_commitment = foldScalar(
    "aac/vnet-bn254-g1/1/commitment-set",
    atoms.map((atom) => [atom.debit_commitment, atom.credit_commitment, atom.basis_commitment]),
  );
  link.transition_report = transitionReportFor(link.vnet);
  link.link_certificates = atoms.map(certificateFor);
  return link;
}

function updateVnetAtom(atom, debit, credit) {
  if (!atom) throw new FundraiseDemoRunnerError("vnet_atom_missing");
  atom.debit = debit;
  atom.credit = credit;
  atom.debit_commitment = encodePoint(commitVector(debit, atom.debit_blinding, atom.basis_type_ids));
  atom.credit_commitment = encodePoint(commitVector(credit, atom.credit_blinding, atom.basis_type_ids));
}

function normalizeVariableFillUnits(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const number = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(number) || number < 0) {
    throw new FundraiseDemoRunnerError("bad_variable_fill_units");
  }
  return number;
}

function settlementForUnits(policy, units) {
  const numerator = safeInt(policy.price_numerator, "bad_price_numerator");
  const denominator = safeInt(policy.price_denominator, "bad_price_denominator");
  if (denominator <= 0) throw new FundraiseDemoRunnerError("bad_price_denominator");
  const settlement = units * numerator;
  if (!Number.isSafeInteger(settlement) || settlement % denominator !== 0) {
    throw new FundraiseDemoRunnerError("non_integral_variable_settlement");
  }
  return settlement / denominator;
}

function safeInt(value, reason) {
  if (!Number.isSafeInteger(value)) throw new FundraiseDemoRunnerError(reason);
  return value;
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
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
  const balanceSheetVerifier = receipt.balance_sheet_verifier_receipt ?? {};
  const balanceSheetPacket = receipt.balance_sheet_packet ?? null;
  const balanceSheetState = receipt.balance_sheet_state ?? null;
  const local = receipt.local_settlement ?? null;
  const accepted = receipt.accepted === true;
  const settled = Boolean(local?.transaction_hash);
  const settlementAsset = settlementAssetLabel(policy.settlement_asset_type_id);
  const issuedUnit = issuedUnitLabel(policy.issued_unit_type_id);
  const unitNoun = issuedUnitNoun(policy.issued_unit_type_id);
  const subscriptionSettlementTotal = sumNumbers(subscriptions, "settlement_amount");
  const subscriptionIssuedTotal = sumNumbers(subscriptions, "issued_units");
  const settlementTotal = firstNumber(publicInputs.settlement_amount_total, subscriptionSettlementTotal);
  const issuedTotal = firstNumber(auth.issued_unit_total, publicInputs.issued_unit_total, subscriptionIssuedTotal);
  const orderCapacityUnits = firstNumber(policy.max_issued_units, issuedTotal);
  const recipientCount = Array.isArray(auth.recipients) ? auth.recipients.length : subscriptions.length;
  const pricePerUnit = priceFromPolicy(policy);
  const orderCapacitySettlement = orderCapacityUnits !== null && pricePerUnit !== null
    ? orderCapacityUnits * pricePerUnit
    : firstNumber(policy.max_settlement_amount, settlementTotal);
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
  const openAfter = Math.max(0, (orderCapacityUnits ?? issuedTotal ?? 0) - filledUnits);
  const reconciliationAccepted =
    settlementTotal !== null
    && issuedTotal !== null
    && orderCapacityUnits !== null
    && filledSettlement === settlementTotal
    && filledUnits === issuedTotal
    && filledUnits <= orderCapacityUnits;
  return {
    schema: FUNDRAISE_DEMO_SUMMARY_SCHEMA,
    accepted,
    status: accepted ? (settled ? "settled-local" : "authorized-pending-signature") : "ready-to-run",
    vector_id: receipt.vector_id,
    round_id: receipt.packet_round_id ?? publicInputs.round_id ?? null,
    issuer_name: publicInputs.issuer_name ?? null,
    metrics: [
      { value: amountValue(orderCapacitySettlement), label: `${settlementAsset} order cap` },
      { value: amountValue(issuedTotal), label: `${issuedUnit} in batch` },
      { value: amountValue(openAfter), label: `${unitNoun} open` },
    ],
    order: {
      headline: orderCapacityUnits !== null && issuedTotal !== null
        ? `Fill ${amountValue(issuedTotal)} of ${amountValue(orderCapacityUnits)} ${issuedUnit}`
        : `Sell ${amountValue(issuedTotal)} ${issuedUnit}`,
      price_label: pricePerUnit === null ? "price unavailable" : `${amountValue(pricePerUnit)} ${settlementAsset} / ${singularUnit(unitNoun)}`,
      settlement_asset: settlementAsset,
      issued_unit: issuedUnit,
      issued_unit_noun: unitNoun,
      price_per_unit: pricePerUnit,
      max_settlement_amount: orderCapacitySettlement,
      max_issued_units: orderCapacityUnits,
      filled_issued_units: issuedTotal,
      open_issued_units: openAfter,
    },
    fills,
    opening_balances: [
      { label: `${settlementAsset} collected`, value: amountWithUnit(0, settlementAsset) },
      { label: `${unitNoun} issued`, value: amountWithUnit(0, unitNoun) },
      { label: `${unitNoun} open`, value: amountWithUnit(orderCapacityUnits, unitNoun) },
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
          opening: amountWithUnit(orderCapacityUnits, unitNoun),
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
    balance_sheet: {
      accepted: balanceSheetVerifier.accepted === true,
      status: balanceSheetVerifier.accepted === true ? "accepted" : "not-run",
      status_label: balanceSheetVerifier.accepted === true
        ? `${verifierModeLabel(balanceSheetVerifier.mode)} accepted`
        : "balance-sheet verifier not run",
      target_label: balanceSheetVerifier.mode
        ? `${verifierModeLabel(balanceSheetVerifier.mode)} · balance sheet`
        : "ProveKit balance-sheet verifier",
      verifier_id: balanceSheetVerifier.verifier_id ?? null,
      verifier_profile: balanceSheetVerifier.verifier_profile ?? null,
      proof_system: balanceSheetVerifier.proof_system ?? receipt.balance_sheet_provekit?.proof_system ?? null,
      mode: balanceSheetVerifier.mode ?? receipt.balance_sheet_provekit?.mode ?? null,
      fundraise_packet_commitment: balanceSheetPacket?.fundraise_packet_commitment ?? null,
      packet_commitment: balanceSheetVerifier.packet_commitment ?? null,
      public_inputs_commitment: balanceSheetVerifier.public_inputs_commitment ?? null,
      proof_ref: balanceSheetVerifier.proof_ref ?? receipt.balance_sheet_provekit?.proof_ref ?? null,
      proof_digest: balanceSheetVerifier.proof_digest ?? receipt.balance_sheet_provekit?.proof_digest ?? null,
      verifier_key_digest: balanceSheetVerifier.verifier_key_digest
        ?? receipt.balance_sheet_provekit?.verifier_key_digest
        ?? null,
      receipt_digest: balanceSheetVerifier.receipt_digest ?? null,
      adapter_schema: balanceSheetVerifier.adapter_schema ?? null,
      timings_ms: balanceSheetVerifier.timings_ms ?? receipt.balance_sheet_provekit?.timings_ms ?? {},
      roots: balanceSheetState?.roots ?? {
        prev_balance_sheet_root: publicInputs.prev_balance_sheet_root ?? null,
        next_balance_sheet_root: publicInputs.next_balance_sheet_root ?? null,
      },
      public_inputs: balanceSheetState?.public_inputs ?? balanceSheetPacket?.public_inputs ?? {},
      rows: balanceSheetState?.rows ?? balanceSheetPacket?.rows ?? [],
      boundary: balanceSheetPacket?.boundary
        ?? "Proves private before/after state arithmetic for the selected batch; starting balance-sheet truth still needs an external anchor.",
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
      accepted
        ? "ProveKit accepted the VNET proof for the selected fundraise batch."
        : "The selected batch has been rebuilt into a fundraise packet but not proven yet.",
      accepted
        ? "The workflow authorized an EVM mint bound to the proof receipt and recipient set."
        : "Generate proof to bind the selected batch to the ProveKit receipt and workflow authorization.",
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
    DEFAULT_BALANCE_SHEET_PROOF,
    "public.json",
    DEFAULT_PROVEKIT_PROVER_KEY,
    DEFAULT_PROVEKIT_VERIFIER_KEY,
    DEFAULT_BALANCE_SHEET_PROVER_KEY,
    DEFAULT_BALANCE_SHEET_VERIFIER_KEY,
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
