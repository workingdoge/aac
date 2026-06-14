#!/usr/bin/env node
import { writeFile } from "node:fs/promises";

import { runFundraiseDemo, runFundraiseDemoLocalSettlement } from "../src/index.mjs";

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  process.stdout.write(`Usage: aac-fundraise-demo [--repo-root PATH] [--provekit-bin PATH] [--out PATH] [--keep-workdir]
       aac-fundraise-demo --summary [--settle-local] [--out PATH]
       aac-fundraise-demo --settle-local --rpc-url URL [--forge-bin PATH] [--cast-bin PATH] [--solc-bin PATH]\n`);
  process.exit(0);
}

const input = {
  repo_root: args.repoRoot,
  provekit_bin: args.provekitBin,
  keep_workdir: args.keepWorkdir,
  registry_dir: args.registryDir,
  rpc_url: args.rpcUrl,
  forge_bin: args.forgeBin,
  cast_bin: args.castBin,
  solc_bin: args.solcBin,
  deployer_private_key: args.deployerPrivateKey,
  authorizer_private_key: args.authorizerPrivateKey,
};
const result = args.settleLocal
  ? await runFundraiseDemoLocalSettlement(input)
  : await runFundraiseDemo(input);
const output = args.summary ? result.summary : result;
const json = `${JSON.stringify(output, null, 2)}\n`;
if (args.out) {
  await writeFile(args.out, json);
} else {
  process.stdout.write(json);
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") out.help = true;
    else if (arg === "--keep-workdir") out.keepWorkdir = true;
    else if (arg === "--settle-local") out.settleLocal = true;
    else if (arg === "--summary") out.summary = true;
    else if (arg === "--repo-root") out.repoRoot = needValue(argv, ++i, arg);
    else if (arg === "--provekit-bin") out.provekitBin = needValue(argv, ++i, arg);
    else if (arg === "--registry-dir") out.registryDir = needValue(argv, ++i, arg);
    else if (arg === "--rpc-url") out.rpcUrl = needValue(argv, ++i, arg);
    else if (arg === "--forge-bin") out.forgeBin = needValue(argv, ++i, arg);
    else if (arg === "--cast-bin") out.castBin = needValue(argv, ++i, arg);
    else if (arg === "--solc-bin") out.solcBin = needValue(argv, ++i, arg);
    else if (arg === "--deployer-private-key") out.deployerPrivateKey = needValue(argv, ++i, arg);
    else if (arg === "--authorizer-private-key") out.authorizerPrivateKey = needValue(argv, ++i, arg);
    else if (arg === "--out") out.out = needValue(argv, ++i, arg);
    else throw new Error(`unknown argument: ${arg}`);
  }
  return out;
}

function needValue(argv, index, flag) {
  const value = argv[index];
  if (!value) throw new Error(`${flag} requires a value`);
  return value;
}
