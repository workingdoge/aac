# Threshold Brief: cand-0038-provekit-beta19

Generated: 2026-06-14T04:32:27Z
Status: validated
Intent: Make the ProveKit receipt circuit (world-app/provekit-circuit) actually compile, test, and execute on its declared Noir beta.19 toolchain, and bring beta.19 in reproducibly via Nix. Three scaffold bugs (cand-0027) had never been exercised because no beta.19 toolchain existed: (1) Nargo.toml pinned an invalid prerelease compiler_version (beta.19 rejects any prerelease requirement -> package would not load) -> remove it; (2) hash.nr imported the private std::hash::poseidon2::Poseidon2::hash -> rewrite as a width-4/rate-3 sponge over the PUBLIC poseidon2_permutation, identical construction to circuits/hash (cand-0024); (3) Prover.toml.example carried 0x00 placeholders -> regenerate the real sponge-hash commitments so nargo execute solves. Add an ADDITIVE flake package nargo19 (hash-pinned beta.19 nargo for all four release triples, same mechanism as the beta.14 nargo) kept OFF the dev-shell PATH and out of the default package so the beta.14 circuits/ workspace is untouched. Witnessed: nargo19 (beta.19) compile clean + 8 tests passed + witness solved on the regenerated example; flake nargo19 evaluates.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/flake.nix` replaces `flake.nix`: +55/-1 lines vs live
- `cargo/world-app/provekit-circuit/Nargo.toml` replaces `world-app/provekit-circuit/Nargo.toml`: +8/-4 lines vs live
- `cargo/world-app/provekit-circuit/Prover.toml.example` replaces `world-app/provekit-circuit/Prover.toml.example`: +11/-10 lines vs live
- `cargo/world-app/provekit-circuit/src/hash.nr` replaces `world-app/provekit-circuit/src/hash.nr`: +26/-7 lines vs live

## Witnessed behavioral delta (task: Make world-app/provekit-circuit (the ProveKit EVENT/1 re-expression) compile/test/execute on its declared Noir beta.19 toolchain, and bring beta.19 in reproducibly via Nix. Three never-exercised scaffold bugs fixed: (1) removed the invalid prerelease compiler_version pin (beta.19 rejects any prerelease requirement, so the package would not load); (2) rewrote hash.nr from the private Poseidon2::hash to a width-4/rate-3 sponge over the PUBLIC poseidon2_permutation (identical to circuits/hash cand-0024); (3) regenerated Prover.toml.example from 0x00 placeholders to the real sponge-hash commitments so execute solves. Added an ADDITIVE flake package nargo19 (hash-pinned beta.19 nargo, four triples, same mechanism as the beta.14 nargo) kept off the dev-shell PATH and out of the default package so the beta.14 circuits/ workspace is untouched. Witnessed: structural (three fixes + additive flake package); beta.19 compile clean + nargo test 8/8 + witness solved on the regenerated example; the flake nargo19 attribute builds to a beta.19 binary.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
