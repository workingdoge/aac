import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

import {
  FUNDRAISE_DEMO_RUNNER_SCHEMA,
  loadFundraiseDemoPacket,
  prepareProveKitWorkdir,
  runFundraiseDemo,
} from "../src/index.mjs";

const repoRoot = resolve(import.meta.dirname, "../..");

const packet = await loadFundraiseDemoPacket({ repo_root: repoRoot });
assert.equal(packet.public_inputs.issued_unit_total, 150);

const work = await prepareProveKitWorkdir({ repo_root: repoRoot, keep_workdir: true });
assert.equal(work.circuit_dir.endsWith("provekit-vnet"), true);

const fakeWork = await mkdtemp(resolve(tmpdir(), "aac-demo-runner-test."));
await mkdir(resolve(fakeWork, "circuit"), { recursive: true });
await writeFile(resolve(fakeWork, "circuit", "Nargo.toml"), "[package]\nname = \"fake\"\n");
await writeFile(resolve(fakeWork, "circuit", "Prover.toml.example"), "accepted = true\n");
const commands = [];
const receipt = await runFundraiseDemo({
  repo_root: repoRoot,
  circuit_dir: resolve(fakeWork, "circuit"),
  provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
  run_command: async (command) => {
    commands.push(command);
    if (command.step === "prepare") {
      await writeFile(command.args[command.args.indexOf("-p") + 1], new Uint8Array([1, 2, 3]));
      await writeFile(command.args[command.args.indexOf("-v") + 1], new Uint8Array([4, 5, 6]));
    }
    if (command.step === "prove") {
      await writeFile(command.args[command.args.indexOf("-o") + 1], new Uint8Array([7, 8, 9]));
    }
    return { exit_code: 0, stdout: `${command.step}: ok\n` };
  },
});
assert.equal(receipt.schema, FUNDRAISE_DEMO_RUNNER_SCHEMA);
assert.equal(receipt.accepted, true);
assert.deepEqual(commands.map((command) => command.step), ["prepare", "prove", "verify"]);
assert.equal(receipt.provekit.mode, "native-cli");
assert.equal(receipt.provekit.proof_system, "provekit-whir");
assert.match(receipt.provekit.proof_digest, /^0x[0-9a-f]{64}$/);
assert.match(receipt.provekit.verifier_key_digest, /^0x[0-9a-f]{64}$/);
assert.equal(receipt.workflow_receipt.accepted, true);
assert.equal(receipt.settlement_action.method, "settle");
assert.equal(receipt.settlement_action.args.signature, null);
assert.equal(receipt.settlement_action.args.auth.issued_unit_total, 150);

await assert.rejects(
  () =>
    runFundraiseDemo({
      repo_root: repoRoot,
      circuit_dir: resolve(fakeWork, "circuit"),
      provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
      run_command: async (command) => {
        if (command.step === "prepare") {
          await writeFile(command.args[command.args.indexOf("-p") + 1], new Uint8Array([1, 2, 3]));
          await writeFile(command.args[command.args.indexOf("-v") + 1], new Uint8Array([4, 5, 6]));
        }
        if (command.step === "prove") {
          await writeFile(command.args[command.args.indexOf("-o") + 1], new Uint8Array([7, 8, 9]));
        }
        return { exit_code: command.step === "verify" ? 2 : 0, stderr: "bad proof\n" };
      },
    }),
  /provekit verify failed/,
);

console.log("fundraise-demo-runner tests: pass");
