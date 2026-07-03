import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildProveKitVerifierReceiptFromNativeCli,
  buildProveKitVerifierReceipt,
  normalizeProveKitResult,
  runProveKitNativeCli,
  verifyProveKitVerifierReceipt,
} from "../src/index.mjs";
import {
  authorizeFundraiseWorkflow,
  createWorkflowPolicy,
  verifyWorkflowReceipt,
} from "../../fundraise-workflow/src/index.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = resolve(here, "../../sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const packet = fixture.vectors.find((vector) => vector.id === "fundraise-demo-good").packet;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const provekit = {
  accepted: true,
  proof_system: "provekit-whir",
  mode: "native-cli",
  proof: new Uint8Array([1, 2, 3, 4]),
  public_inputs: packet.public_inputs,
  verifier_key_digest: "0x" + "ab".repeat(32),
  timings_ms: { prove: 400, verify: 40 },
};

const normalized = normalizeProveKitResult(provekit);
assert.equal(normalized.proof_system, "provekit-whir");
assert.equal(normalized.mode, "native-cli");
assert.match(normalized.proof_digest, /^0x[0-9a-f]{64}$/);
assert.equal(normalized.verifier_key_digest, "0x" + "ab".repeat(32));

const receipt = buildProveKitVerifierReceipt({ packet, provekit });
assert.equal(receipt.accepted, true);
assert.equal(receipt.proof_system, "provekit-whir");
assert.equal(receipt.mode, "native-cli");
assert.equal(verifyProveKitVerifierReceipt(receipt, { packet }).accepted, true);

const cliDir = await mkdtemp(resolve(tmpdir(), "aac-provekit-cli-adapter."));
try {
  await writeFile(resolve(cliDir, "Prover.toml"), "accepted = true\n");
  await writeFile(resolve(cliDir, "proof.np"), new Uint8Array([9, 8, 7, 6]));
  await writeFile(resolve(cliDir, "demo.pkv"), new Uint8Array([6, 7, 8, 9]));
  const commands = [];
  const cliReceipt = await buildProveKitVerifierReceiptFromNativeCli({
    packet,
    cli: {
      provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
      circuit_dir: cliDir,
      cwd: cliDir,
      prover_toml: "Prover.toml",
      prover_key: "demo.pkp",
      verifier_key: "demo.pkv",
      proof: "proof.np",
      run_command: async (command) => {
        commands.push({
          step: command.step,
          executable: command.executable,
          args: command.args,
          cwd: command.cwd,
        });
        return { exit_code: 0, stdout: `${command.step}: ok\n` };
      },
    },
  });
  assert.deepEqual(commands.map((command) => command.step), ["prepare", "prove", "verify"]);
  assert.equal(commands[0].executable, "/nix/store/fake-provekit-cli/bin/provekit-cli");
  assert.deepEqual(commands[0].args, [
    "prepare",
    "--deny-warnings",
    "--force",
    "-p",
    resolve(cliDir, "demo.pkp"),
    "-v",
    resolve(cliDir, "demo.pkv"),
    cliDir,
  ]);
  assert.deepEqual(commands[1].args, [
    "prove",
    "-p",
    resolve(cliDir, "demo.pkp"),
    "-i",
    resolve(cliDir, "Prover.toml"),
    "-o",
    resolve(cliDir, "proof.np"),
  ]);
  assert.deepEqual(commands[2].args, [
    "verify",
    "-v",
    resolve(cliDir, "demo.pkv"),
    "--proof",
    resolve(cliDir, "proof.np"),
  ]);
  assert.equal(cliReceipt.verifier_id, "provekit-native-cli");
  assert.equal(cliReceipt.proof_system, "provekit-whir");
  assert.equal(cliReceipt.mode, "native-cli");
  assert.match(cliReceipt.proof_digest, /^0x[0-9a-f]{64}$/);
  assert.match(cliReceipt.verifier_key_digest, /^0x[0-9a-f]{64}$/);
  assert.equal(verifyProveKitVerifierReceipt(cliReceipt, { packet }).accepted, true);

  await assert.rejects(
    () =>
      runProveKitNativeCli({
        public_inputs: packet.public_inputs,
        provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
        circuit_dir: cliDir,
        cwd: cliDir,
        prover_toml: "Prover.toml",
        verifier_key: "demo.pkv",
        proof: "proof.np",
        run_command: async (command) => ({
          exit_code: command.step === "verify" ? 42 : 0,
          stderr: command.step === "verify" ? "bad proof\n" : "",
        }),
      }),
    (err) => err.reason === "provekit_cli_verify_failed" && err.detail.exit_code === 42,
  );
} finally {
  await rm(cliDir, { recursive: true, force: true });
}

const policy = createWorkflowPolicy({ require_live_proof: true });
const workflow = authorizeFundraiseWorkflow({ packet, verifier_receipt: receipt, policy });
assert.equal(workflow.accepted, true);
assert.equal(workflow.settlement_action.args.auth.issued_unit_total, 150);
assert.equal(verifyWorkflowReceipt(workflow).accepted, true);

assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, accepted: false, reason: "bad proof" } }),
  /bad proof/,
);
assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, proof_system: "runtime-reference" } }),
  /bad_proof_system/,
);
assert.throws(
  () => buildProveKitVerifierReceipt({ packet, provekit: { ...provekit, verifier_key_digest: "0x1234" } }),
  /bad_verifier_key_digest/,
);

const tampered = clone(receipt);
tampered.proof_digest = "0x" + "11".repeat(32);
assert.equal(verifyProveKitVerifierReceipt(tampered, { packet }).reason, "verifier_receipt_digest_mismatch");

const stalePacket = clone(packet);
stalePacket.public_inputs.issued_unit_total += 1;
assert.equal(verifyProveKitVerifierReceipt(receipt, { packet: stalePacket }).reason, "verifier_packet_mismatch");

console.log("fundraise-provekit-adapter tests: pass");
