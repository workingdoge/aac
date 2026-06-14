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

export class FundraiseDemoRunnerError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseDemoRunnerError";
    this.reason = reason;
    this.detail = detail;
  }
}

export async function runFundraiseDemo(input = {}) {
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
    const workflowPolicy = createWorkflowPolicy({
      require_live_proof: true,
      ...(input.workflow_policy ?? {}),
    });
    const workflowReceipt = authorizeFundraiseWorkflow({
      packet,
      verifier_receipt: verifierReceipt,
      policy: workflowPolicy,
      recipient_overrides: input.recipient_overrides,
      verify_options: input.verify_options,
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

    return {
      schema: FUNDRAISE_DEMO_RUNNER_SCHEMA,
      accepted: true,
      reason: "accepted",
      vector_id: input.vector_id ?? DEFAULT_VECTOR_ID,
      packet_round_id: packet.public_inputs?.round_id ?? packet.round_policy?.round_id ?? null,
      provekit: {
        mode: verifierReceipt.mode,
        proof_system: verifierReceipt.proof_system,
        proof_ref: verifierReceipt.proof_ref,
        proof_digest: verifierReceipt.proof_digest,
        verifier_key_digest: verifierReceipt.verifier_key_digest,
        timings_ms: verifierReceipt.timings_ms,
      },
      verifier_receipt: verifierReceipt,
      workflow_receipt: workflowReceipt,
      settlement_action: workflowReceipt.settlement_action,
      workdir: input.keep_workdir ? work.work_dir : null,
    };
  } finally {
    if (!input.keep_workdir) {
      await rm(work.work_dir, { recursive: true, force: true });
    }
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

function defaultRepoRoot() {
  return resolve(dirname(fileURLToPath(import.meta.url)), "../..");
}
