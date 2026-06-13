# Threshold Brief: cand-0019-registry-deployable

Generated: 2026-06-13T18:09:29Z
Status: validated
Intent: Make the 4/REG registry actually deployable: the bb HonkVerifier is 24,644B runtime (68 over EIP-170) at optimizer_runs=200 — drop to 50 (23,782B, 794 under) so it deploys on a real EVM, correctness unchanged (forge test still green). Add registry/script/Deploy.s.sol (deploys the verifier + auto-links its ZKTranscriptLib + the Registry pinned to it); verified deploying to live anvil under EIP-170 (ONCHAIN EXECUTION SUCCESSFUL).
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/registry/foundry.toml` replaces `registry/foundry.toml`: +4/-2 lines vs live
- `cargo/registry/README.md` replaces `registry/README.md`: +23/-0 lines vs live
- `cargo/registry/script/Deploy.s.sol` is NEW at `registry/script/Deploy.s.sol`: 24 lines

## Witnessed behavioral delta (task: make the 4/REG registry deployable — HonkVerifier under EIP-170 at optimizer_runs=50, forge test still green (real proof verifies), and the Deploy script deploys+links the verifier library + Registry)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
