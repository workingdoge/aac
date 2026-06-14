#!/usr/bin/env node
import { writeFile } from "node:fs/promises";

import { runFundraiseDemo } from "../src/index.mjs";

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  process.stdout.write(`Usage: aac-fundraise-demo [--repo-root PATH] [--provekit-bin PATH] [--out PATH] [--keep-workdir]\n`);
  process.exit(0);
}

const result = await runFundraiseDemo({
  repo_root: args.repoRoot,
  provekit_bin: args.provekitBin,
  keep_workdir: args.keepWorkdir,
});
const json = `${JSON.stringify(result, null, 2)}\n`;
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
    else if (arg === "--repo-root") out.repoRoot = needValue(argv, ++i, arg);
    else if (arg === "--provekit-bin") out.provekitBin = needValue(argv, ++i, arg);
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
