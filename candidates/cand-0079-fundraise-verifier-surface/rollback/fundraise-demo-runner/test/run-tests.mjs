import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

import {
  FUNDRAISE_DEMO_RUNNER_SCHEMA,
  FUNDRAISE_DEMO_SUMMARY_SCHEMA,
  FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA,
  buildFundraiseDemoCorsHeaders,
  buildFundraiseDemoSummary,
  fundraiseStaticContentType,
  loadFundraiseDemoPacket,
  prepareProveKitWorkdir,
  resolveFundraiseStaticPath,
  runFundraiseDemo,
  runFundraiseDemoLocalSettlement,
  runFundraiseDemoServerAction,
} from "../src/index.mjs";

const repoRoot = resolve(import.meta.dirname, "../..");

async function satisfyFakeProveKitCommand(command) {
  if (command.step === "prepare") {
    await writeFile(command.args[command.args.indexOf("-p") + 1], new Uint8Array([1, 2, 3]));
    await writeFile(command.args[command.args.indexOf("-v") + 1], new Uint8Array([4, 5, 6]));
  }
  if (command.step === "prove") {
    await writeFile(command.args[command.args.indexOf("-o") + 1], new Uint8Array([7, 8, 9]));
  }
  return { exit_code: 0, stdout: `${command.step}: ok\n` };
}

const packet = await loadFundraiseDemoPacket({ repo_root: repoRoot });
assert.equal(packet.public_inputs.issued_unit_total, 150);

const work = await prepareProveKitWorkdir({ repo_root: repoRoot, keep_workdir: true });
assert.equal(work.circuit_dir.endsWith("provekit-vnet"), true);

const fakeWork = await mkdtemp(resolve(tmpdir(), "aac-demo-runner-test."));
await mkdir(resolve(fakeWork, "circuit"), { recursive: true });
await writeFile(resolve(fakeWork, "circuit", "Nargo.toml"), "[package]\nname = \"fake\"\n");
await writeFile(resolve(fakeWork, "circuit", "Prover.toml.example"), "accepted = true\n");
await mkdir(resolve(fakeWork, "static", "fundraise"), { recursive: true });
await mkdir(resolve(fakeWork, "static", "_astro"), { recursive: true });
await writeFile(resolve(fakeWork, "static", "index.html"), "<aac-fundraise-demo></aac-fundraise-demo>\n");
await writeFile(resolve(fakeWork, "static", "fundraise", "index.html"), "<h1>fundraise</h1>\n");
await writeFile(resolve(fakeWork, "static", "_astro", "app.js"), "console.log('demo');\n");
assert.equal(
  await resolveFundraiseStaticPath(resolve(fakeWork, "static"), "/fundraise/"),
  resolve(fakeWork, "static", "fundraise", "index.html"),
);
assert.equal(
  await resolveFundraiseStaticPath(resolve(fakeWork, "static"), "/_astro/app.js"),
  resolve(fakeWork, "static", "_astro", "app.js"),
);
assert.equal(await resolveFundraiseStaticPath(resolve(fakeWork, "static"), "/../secret"), null);
assert.equal(fundraiseStaticContentType("index.html"), "text/html; charset=utf-8");
assert.equal(fundraiseStaticContentType("app.js"), "text/javascript; charset=utf-8");
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
assert.equal(receipt.public_inputs.round_id, "aac-seed-2026-001");
assert.equal(receipt.packet_projection.round_policy.settlement_asset_type_id, "USDC:arc-testnet:atomic");
assert.deepEqual(
  receipt.packet_projection.subscriptions.map((item) => [item.investor_id, item.settlement_amount, item.issued_units]),
  [
    ["investor-a", 1000, 100],
    ["investor-b", 500, 50],
  ],
);
assert.equal(receipt.summary.schema, FUNDRAISE_DEMO_SUMMARY_SCHEMA);
assert.equal(receipt.summary.status, "authorized-pending-signature");
assert.equal(receipt.summary.round_id, "aac-seed-2026-001");
assert.equal(receipt.summary.issuer_name, "issuer-a.private-row");
assert.equal(receipt.summary.economics.settlement_amount_total, 1500);
assert.equal(receipt.summary.economics.issued_unit_total, 150);
assert.equal(receipt.summary.economics.recipient_count, 2);
assert.deepEqual(receipt.summary.metrics, [
  { value: "1500", label: "USDC order size" },
  { value: "150", label: "restricted SAFE receipt units" },
  { value: "2", label: "fills in batch" },
]);
assert.deepEqual(receipt.summary.order, {
  headline: "Sell 150 restricted SAFE receipt units",
  price_label: "10 USDC / unit",
  settlement_asset: "USDC",
  issued_unit: "restricted SAFE receipt units",
  issued_unit_noun: "units",
  price_per_unit: 10,
});
assert.deepEqual(receipt.summary.fills.map((item) => ({
  party: item.party,
  settlement_label: item.settlement_label,
  issued_label: item.issued_label,
  recipient: item.recipient,
})), [
  {
    party: "investor-a",
    settlement_label: "1000 USDC",
    issued_label: "100 units",
    recipient: "0xA11ce00000000000000000000000000000000039",
  },
  {
    party: "investor-b",
    settlement_label: "500 USDC",
    issued_label: "50 units",
    recipient: "0xB0b000000000000000000000000000000000039",
  },
]);
assert.deepEqual(receipt.summary.opening_balances, [
  { label: "USDC collected", value: "0 USDC" },
  { label: "units issued", value: "0 units" },
  { label: "units open", value: "150 units" },
]);
assert.equal(receipt.summary.reconciliation.accepted, true);
assert.deepEqual(receipt.summary.reconciliation.rows, [
  { line: "USDC collected", opening: "0 USDC", delta: "+1500 USDC", closing: "1500 USDC" },
  { line: "units issued", opening: "0 units", delta: "+150 units", closing: "150 units" },
  { line: "units open", opening: "150 units", delta: "-150 units", closing: "0 units" },
]);
assert.equal(receipt.summary.commitments.transition_set, receipt.public_inputs.transition_set_commitment);
assert.equal(receipt.summary.proof.proof_digest, receipt.provekit.proof_digest);
assert.equal(receipt.summary.workflow.signature_status, "pending");
assert.equal(receipt.summary.settlement.total_supply, null);
assert.ok(receipt.summary.caveats.some((item) => item.includes("production recursive/on-chain VNET")));
assert.deepEqual(buildFundraiseDemoSummary(receipt), receipt.summary);
assert.deepEqual(commands.map((command) => command.step), ["prepare", "prove", "verify"]);
assert.equal(receipt.provekit.mode, "native-cli");
assert.equal(receipt.provekit.proof_system, "provekit-whir");
assert.match(receipt.provekit.proof_digest, /^0x[0-9a-f]{64}$/);
assert.match(receipt.provekit.verifier_key_digest, /^0x[0-9a-f]{64}$/);
assert.equal(receipt.workflow_receipt.accepted, true);
assert.equal(receipt.settlement_action.method, "settle");
assert.equal(receipt.settlement_action.args.signature, null);
assert.equal(receipt.settlement_action.args.auth.issued_unit_total, 150);

const envProveKitCommands = [];
const previousProveKitBin = process.env.PROVEKIT_BIN;
process.env.PROVEKIT_BIN = "./result/bin/provekit-cli";
try {
  await runFundraiseDemo({
    repo_root: repoRoot,
    circuit_dir: resolve(fakeWork, "circuit"),
    run_command: async (command) => {
      envProveKitCommands.push(command);
      return satisfyFakeProveKitCommand(command);
    },
  });
} finally {
  if (previousProveKitBin === undefined) {
    delete process.env.PROVEKIT_BIN;
  } else {
    process.env.PROVEKIT_BIN = previousProveKitBin;
  }
}
assert.deepEqual(envProveKitCommands.map((command) => command.step), ["prepare", "prove", "verify"]);
assert.ok(envProveKitCommands.every((command) => command.executable === resolve(repoRoot, "result/bin/provekit-cli")));
assert.ok(envProveKitCommands.every((command) => command.cwd !== repoRoot));

const foundryCommands = [];
let balanceCalls = 0;
const local = await runFundraiseDemoLocalSettlement({
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
    return { exit_code: 0, stdout: `${command.step}: ok\n` };
  },
  foundry_command: async (command) => {
    foundryCommands.push(command);
    const joined = command.args.join(" ");
    if (joined.includes("wallet address")) {
      return { stdout: "0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7\n" };
    }
    if (command.executable.endsWith("forge") && joined.includes("FundraiseReceiptToken")) {
      return {
        stdout: JSON.stringify({
          deployedTo: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
          transactionHash: "0x" + "11".repeat(32),
        }),
      };
    }
    if (command.executable.endsWith("forge") && joined.includes("FundraiseMintSettlement")) {
      return {
        stdout: JSON.stringify({
          deployedTo: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
          transactionHash: "0x" + "22".repeat(32),
        }),
      };
    }
    if (joined.includes("settlementDigest")) {
      return { stdout: "0x" + "33".repeat(32) + "\n" };
    }
    if (joined.includes("wallet sign")) {
      return { stdout: "0x" + "44".repeat(65) + "\n" };
    }
    if (joined.includes("balanceOf")) {
      balanceCalls += 1;
      return { stdout: `${balanceCalls === 1 ? 100 : 50}\n` };
    }
    if (joined.includes("totalSupply")) {
      return { stdout: "150\n" };
    }
    if (joined.includes("setMinter") || joined.includes("settle(")) {
      return { stdout: JSON.stringify({ transactionHash: "0x" + "55".repeat(32) }) };
    }
    throw new Error(`unexpected foundry command: ${command.executable} ${joined}`);
  },
  forge_bin: "/nix/store/fake-foundry/bin/forge",
  cast_bin: "/nix/store/fake-foundry/bin/cast",
  solc_bin: "/nix/store/fake-solc/bin/solc",
});
assert.equal(local.schema, FUNDRAISE_DEMO_RUNNER_SCHEMA);
assert.equal(local.local_settlement.schema, FUNDRAISE_LOCAL_SETTLEMENT_SCHEMA);
assert.equal(local.summary.schema, FUNDRAISE_DEMO_SUMMARY_SCHEMA);
assert.equal(local.summary.status, "settled-local");
assert.equal(local.summary.workflow.signature_status, "submitted");
assert.equal(local.local_settlement.total_supply, 150);
assert.equal(local.summary.settlement.total_supply, 150);
assert.deepEqual(local.local_settlement.balances.map((item) => item.amount), [100, 50]);
assert.deepEqual(local.summary.settlement.balances.map((item) => item.amount), [100, 50]);
assert.equal(local.local_settlement.transaction_hash, "0x" + "55".repeat(32));
assert.equal(local.summary.settlement.transaction_hash, "0x" + "55".repeat(32));
assert.ok(local.summary.claims.some((item) => item.includes("refused replay")));
assert.equal(foundryCommands.filter((command) => command.executable.endsWith("forge")).length, 2);
assert.ok(foundryCommands.some((command) => command.args.includes("setMinter(address)")));
assert.ok(foundryCommands.some((command) => command.args.includes("settle((bytes32,address,bytes32,bytes32,uint256,(address,uint256)[]),bytes)")));

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

const serverCommands = [];
const serverPayload = await runFundraiseDemoServerAction({
  repo_root: repoRoot,
  circuit_dir: resolve(fakeWork, "circuit"),
  provekit_bin: "/nix/store/fake-provekit-cli/bin/provekit-cli",
  run_command: async (command) => {
    serverCommands.push(command);
    if (command.step === "prepare") {
      await writeFile(command.args[command.args.indexOf("-p") + 1], new Uint8Array([1, 2, 3]));
      await writeFile(command.args[command.args.indexOf("-v") + 1], new Uint8Array([4, 5, 6]));
    }
    if (command.step === "prove") {
      await writeFile(command.args[command.args.indexOf("-o") + 1], new Uint8Array([7, 8, 9]));
    }
    return { exit_code: 0, stdout: `${command.step}: ok\n` };
  },
}, {
  path: "/api/fundraise/run?settle_local=false",
  body: {
    settle_local: false,
    provekit_bin: "/tmp/must-not-run",
    repo_root: "/tmp/must-not-read",
  },
});
assert.equal(serverPayload.accepted, true);
assert.equal(serverPayload.mode, "live-proof");
assert.equal(serverPayload.summary.status, "authorized-pending-signature");
assert.equal(serverPayload.summary.proof.proof_system, "provekit-whir");
assert.deepEqual(serverCommands.map((command) => command.step), ["prepare", "prove", "verify"]);
assert.ok(serverCommands.every((command) => command.executable === "/nix/store/fake-provekit-cli/bin/provekit-cli"));

const corsHeaders = buildFundraiseDemoCorsHeaders("http://127.0.0.1:4328");
assert.equal(corsHeaders["access-control-allow-origin"], "http://127.0.0.1:4328");
assert.equal(corsHeaders["access-control-allow-private-network"], "true");
assert.match(corsHeaders.vary, /Access-Control-Request-Private-Network/);

console.log("fundraise-demo-runner tests: pass");
