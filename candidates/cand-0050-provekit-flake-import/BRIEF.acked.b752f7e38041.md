# Threshold Brief: cand-0050-provekit-flake-import

Generated: 2026-06-14T07:35:04Z
Status: validated
Intent: import ProveKit flake package from main into vnet fundraising workspace
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/root/flake.nix` replaces `flake.nix`: +122/-2 lines vs live
- `cargo/root/flake.lock` replaces `flake.lock`: +56/-1 lines vs live
- `cargo/world-app/.gitignore` replaces `world-app/.gitignore`: +3/-0 lines vs live

## Witnessed behavioral delta (task: Import the ProveKit flake package into the vnet fundraising worktree without landing generated proof artifacts.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
