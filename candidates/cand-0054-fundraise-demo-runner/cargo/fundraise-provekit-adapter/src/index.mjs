import { createHash } from "node:crypto";
import { basename, resolve } from "node:path";
import {
  packetCommitment,
  VERIFIER_RECEIPT_SCHEMA,
  verifyVerifierReceipt,
} from "../../fundraise-workflow/src/index.mjs";
import { digestHex } from "../../fundraise-authorizer/src/index.mjs";

export const PROVEKIT_ADAPTER_SCHEMA = "aac.fundraise-provekit-adapter.input.v1";
export const PROVEKIT_PROOF_SYSTEMS = Object.freeze(["provekit-whir", "provekit-groth16"]);
export const PROVEKIT_MODES = Object.freeze(["native-cli", "browser-wasm", "service", "cre-workflow"]);
export const DEFAULT_VERIFIER_PROFILE = "fundraise-runtime/v1+vnet-runtime/v1";
export const DEFAULT_PROVEKIT_BIN = "provekit-cli";

export class FundraiseProveKitAdapterError extends Error {
  constructor(reason, message = reason, detail = {}) {
    super(message);
    this.name = "FundraiseProveKitAdapterError";
    this.reason = reason;
    this.detail = detail;
  }
}

export async function runProveKitNativeCli(input = {}) {
  const config = normalizeProveKitNativeCliInput(input);
  const timings = {};
  if (config.prepare) {
    await runNativeCliStep(
      config,
      "prepare",
      [
        "prepare",
        "--deny-warnings",
        "--force",
        "-p",
        config.prover_key,
        "-v",
        config.verifier_key,
        config.circuit_dir,
      ],
      timings,
    );
  }
  if (config.prove) {
    await runNativeCliStep(
      config,
      "prove",
      ["prove", "-p", config.prover_key, "-i", config.prover_toml, "-o", config.proof],
      timings,
    );
  }
  if (config.verify) {
    await runNativeCliStep(
      config,
      "verify",
      ["verify", "-v", config.verifier_key, "--proof", config.proof],
      timings,
    );
  }

  const proofDigest = await digestFileHex("aac/fundraise-provekit/proof/1", config.proof, "proof_file_missing");
  const verifierKeyDigest = await digestFileHex(
    "aac/fundraise-provekit/verifier-key/1",
    config.verifier_key,
    "verifier_key_file_missing",
  );
  return {
    accepted: true,
    reason: "accepted",
    proof_system: config.proof_system,
    mode: "native-cli",
    public_inputs: config.public_inputs,
    proof_digest: proofDigest,
    proof_ref: config.proof_ref ?? `${config.proof_system}:native-cli:${basename(config.proof)}`,
    verifier_key_digest: verifierKeyDigest,
    timings_ms: timings,
  };
}

export async function buildProveKitVerifierReceiptFromNativeCli({
  packet,
  cli,
  verifier_id = "provekit-native-cli",
  verifier_profile = DEFAULT_VERIFIER_PROFILE,
} = {}) {
  if (!packet || typeof packet !== "object") {
    throw new FundraiseProveKitAdapterError("packet_missing");
  }
  const provekit = await runProveKitNativeCli({
    public_inputs: packet.public_inputs,
    ...(cli ?? {}),
  });
  return buildProveKitVerifierReceipt({
    packet,
    provekit,
    verifier_id,
    verifier_profile,
  });
}

export function buildProveKitVerifierReceipt({
  packet,
  provekit,
  verifier_id = "provekit-verifier",
  verifier_profile = DEFAULT_VERIFIER_PROFILE,
} = {}) {
  if (!packet || typeof packet !== "object") {
    throw new FundraiseProveKitAdapterError("packet_missing");
  }
  const normalized = normalizeProveKitResult(provekit);
  const core = {
    schema: VERIFIER_RECEIPT_SCHEMA,
    accepted: true,
    reason: "accepted",
    verifier_id,
    verifier_profile,
    proof_system: normalized.proof_system,
    mode: normalized.mode,
    packet_commitment: packetCommitment(packet),
    public_inputs_commitment: digestHex(
      "aac/fundraise-provekit/public-inputs/1",
      normalized.public_inputs,
    ),
    proof_ref: normalized.proof_ref,
    proof_digest: normalized.proof_digest,
    verifier_key_digest: normalized.verifier_key_digest,
    timings_ms: normalized.timings_ms,
    adapter_schema: PROVEKIT_ADAPTER_SCHEMA,
  };
  return { ...core, receipt_digest: verifierReceiptDigest(core) };
}

export function verifyProveKitVerifierReceipt(receipt, { packet, policy = {} } = {}) {
  const basic = verifyVerifierReceipt(receipt, { packet, policy });
  if (!basic.accepted) return basic;
  if (!receipt || !PROVEKIT_PROOF_SYSTEMS.includes(receipt.proof_system)) {
    return { accepted: false, reason: "provekit_proof_system_mismatch" };
  }
  if (!PROVEKIT_MODES.includes(receipt.mode)) {
    return { accepted: false, reason: "provekit_mode_mismatch" };
  }
  if (receipt.adapter_schema !== PROVEKIT_ADAPTER_SCHEMA) {
    return { accepted: false, reason: "provekit_adapter_schema_mismatch" };
  }
  if (!isHex32(receipt.verifier_key_digest)) {
    return { accepted: false, reason: "provekit_verifier_key_digest_mismatch" };
  }
  return { accepted: true, reason: "accepted", verifier_receipt: receipt };
}

export function normalizeProveKitResult(provekit) {
  if (!provekit || typeof provekit !== "object") {
    throw new FundraiseProveKitAdapterError("provekit_result_missing");
  }
  if (provekit.accepted !== true) {
    throw new FundraiseProveKitAdapterError("provekit_rejected", provekit.reason ?? "provekit_rejected", {
      provekit_reason: provekit.reason ?? "rejected",
    });
  }
  if (!PROVEKIT_PROOF_SYSTEMS.includes(provekit.proof_system)) {
    throw new FundraiseProveKitAdapterError("bad_proof_system");
  }
  if (!PROVEKIT_MODES.includes(provekit.mode)) {
    throw new FundraiseProveKitAdapterError("bad_provekit_mode");
  }
  if (provekit.public_inputs === undefined || provekit.public_inputs === null) {
    throw new FundraiseProveKitAdapterError("public_inputs_missing");
  }
  const proofDigest = provekit.proof_digest ?? digestBytesOrJson("aac/fundraise-provekit/proof/1", provekit.proof);
  if (!isHex32(proofDigest)) {
    throw new FundraiseProveKitAdapterError("bad_proof_digest");
  }
  const verifierKeyDigest = provekit.verifier_key_digest ?? provekit.vk_digest;
  if (!isHex32(verifierKeyDigest)) {
    throw new FundraiseProveKitAdapterError("bad_verifier_key_digest");
  }
  const timings = provekit.timings_ms ?? {};
  return {
    proof_system: provekit.proof_system,
    mode: provekit.mode,
    public_inputs: provekit.public_inputs,
    proof_digest: hex32(proofDigest),
    proof_ref: provekit.proof_ref ?? `${provekit.proof_system}:${provekit.mode}:${hex32(proofDigest).slice(2, 14)}`,
    verifier_key_digest: hex32(verifierKeyDigest),
    timings_ms: normalizeTimings(timings),
  };
}

function normalizeTimings(timings) {
  const out = {};
  for (const [key, value] of Object.entries(timings)) {
    if (!Number.isFinite(value) || value < 0) {
      throw new FundraiseProveKitAdapterError("bad_timing");
    }
    out[key] = value;
  }
  return out;
}

function normalizeProveKitNativeCliInput(input) {
  if (!input || typeof input !== "object") {
    throw new FundraiseProveKitAdapterError("native_cli_input_missing");
  }
  if (input.public_inputs === undefined || input.public_inputs === null) {
    throw new FundraiseProveKitAdapterError("public_inputs_missing");
  }
  if (!input.circuit_dir) {
    throw new FundraiseProveKitAdapterError("circuit_dir_missing");
  }
  if (!input.prover_toml) {
    throw new FundraiseProveKitAdapterError("prover_toml_missing");
  }
  const proofSystem = input.proof_system ?? "provekit-whir";
  if (!PROVEKIT_PROOF_SYSTEMS.includes(proofSystem)) {
    throw new FundraiseProveKitAdapterError("bad_proof_system");
  }
  const cwd = resolve(input.cwd ?? input.circuit_dir);
  const provekitBin = input.provekit_bin ?? process.env.PROVEKIT_BIN ?? DEFAULT_PROVEKIT_BIN;
  if (typeof provekitBin !== "string" || provekitBin.length === 0) {
    throw new FundraiseProveKitAdapterError("provekit_bin_missing");
  }
  const runCommand = input.run_command ?? defaultNativeCliCommand;
  if (typeof runCommand !== "function") {
    throw new FundraiseProveKitAdapterError("bad_run_command");
  }
  return {
    provekit_bin: provekitBin,
    cwd,
    env: { ...process.env, ...(input.env ?? {}) },
    run_command: runCommand,
    circuit_dir: resolve(cwd, input.circuit_dir),
    prover_toml: resolve(cwd, input.prover_toml),
    prover_key: resolve(cwd, input.prover_key ?? "provekit.pkp"),
    verifier_key: resolve(cwd, input.verifier_key ?? "provekit.pkv"),
    proof: resolve(cwd, input.proof ?? "proof.np"),
    proof_ref: input.proof_ref,
    proof_system: proofSystem,
    public_inputs: input.public_inputs,
    prepare: input.prepare ?? true,
    prove: input.prove ?? true,
    verify: input.verify ?? true,
    timeout_ms: input.timeout_ms ?? 120_000,
    max_buffer: input.max_buffer ?? 16 * 1024 * 1024,
  };
}

async function runNativeCliStep(config, step, args, timings) {
  const started = Date.now();
  const command = {
    step,
    executable: config.provekit_bin,
    args,
    cwd: config.cwd,
    env: config.env,
    timeout_ms: config.timeout_ms,
    max_buffer: config.max_buffer,
  };
  let result;
  try {
    result = await config.run_command(command);
  } catch (err) {
    if (err instanceof FundraiseProveKitAdapterError) throw err;
    throw new FundraiseProveKitAdapterError(`provekit_cli_${step}_failed`, cliFailureMessage(step, err), {
      exit_code: err?.code ?? err?.exit_code ?? null,
      stdout: err?.stdout ?? "",
      stderr: err?.stderr ?? "",
    });
  } finally {
    timings[step] = Date.now() - started;
  }
  const exitCode = result?.exit_code ?? result?.code ?? 0;
  if (exitCode !== 0) {
    throw new FundraiseProveKitAdapterError(`provekit_cli_${step}_failed`, `provekit ${step} failed`, {
      exit_code: exitCode,
      stdout: result?.stdout ?? "",
      stderr: result?.stderr ?? "",
    });
  }
  return result;
}

async function defaultNativeCliCommand(command) {
  const { execFile } = await import("node:child_process");
  return new Promise((resolveCommand, rejectCommand) => {
    execFile(
      command.executable,
      command.args,
      {
        cwd: command.cwd,
        env: command.env,
        timeout: command.timeout_ms,
        maxBuffer: command.max_buffer,
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stdout = stdout;
          error.stderr = stderr;
          rejectCommand(error);
          return;
        }
        resolveCommand({ exit_code: 0, stdout, stderr });
      },
    );
  });
}

function cliFailureMessage(step, err) {
  const message = err?.stderr || err?.message || `provekit ${step} failed`;
  return String(message).trim() || `provekit ${step} failed`;
}

async function digestFileHex(label, file, reason) {
  try {
    const { readFile } = await import("node:fs/promises");
    const bytes = await readFile(file);
    const hash = createHash("sha256");
    hash.update(label);
    hash.update(bytes);
    return `0x${hash.digest("hex")}`;
  } catch (err) {
    throw new FundraiseProveKitAdapterError(reason, `${reason}: ${file}`, {
      file,
      cause: err?.code ?? err?.message ?? "read_error",
    });
  }
}

function verifierReceiptDigest(receipt) {
  const { receipt_digest: _receiptDigest, ...payload } = receipt;
  return hex32(digestHex("aac/fundraise-workflow/verifier-receipt/1", payload));
}

function digestBytesOrJson(label, value) {
  if (value === undefined || value === null) {
    throw new FundraiseProveKitAdapterError("proof_missing");
  }
  const hash = createHash("sha256");
  hash.update(label);
  if (value instanceof Uint8Array) {
    hash.update(value);
  } else if (typeof value === "string") {
    hash.update(value);
  } else {
    hash.update(JSON.stringify(value));
  }
  return `0x${hash.digest("hex")}`;
}

function isHex32(value) {
  if (typeof value !== "string") return false;
  const raw = value.startsWith("0x") ? value.slice(2) : value;
  return /^[0-9a-fA-F]{64}$/.test(raw);
}

function hex32(value) {
  if (!isHex32(value)) throw new FundraiseProveKitAdapterError("bad_bytes32");
  return `0x${(value.startsWith("0x") ? value.slice(2) : value).toLowerCase()}`;
}
