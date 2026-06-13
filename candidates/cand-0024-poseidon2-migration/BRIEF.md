# Threshold Brief: cand-0024-poseidon2-migration

Generated: 2026-06-13T20:15:32Z
Status: validated
Intent: PERF: migrate the circuits' commitment hash from pedersen_hash to a Poseidon2 sponge (vendored over std::hash::poseidon2_permutation, t=3/rate=2/cap=1, capacity initialized with input length for arity domain-separation -- AAC's own commitment hash, deterministic + collision-resistant, no external value to match). New shared circuits/hash lib; swap all 18 pedersen_hash sites across ledger(4)/rulebook(1)/transition(7)/nullify(6); event-complete + pacioli inherit/unchanged. Commitment VALUES change by design (breaks cand-0016 byte-identity -- the point); the registry fixtures/verifiers + web roots regenerate in follow-ups. Headline: pedersen ~3,586 gates/2:1-hash vs poseidon2_permutation ~75 (~48x) on the pedersen-dominated 40,511-gate transition. Witnessed: nargo test green across the workspace + measured bb gates drop.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/hash/Nargo.toml` is NEW at `circuits/hash/Nargo.toml`: 6 lines
- `cargo/circuits/hash/src/lib.nr` is NEW at `circuits/hash/src/lib.nr`: 53 lines
- `cargo/circuits/ledger/Nargo.toml` replaces `circuits/ledger/Nargo.toml`: +2/-0 lines vs live
- `cargo/circuits/ledger/src/lib.nr` replaces `circuits/ledger/src/lib.nr`: +4/-4 lines vs live
- `cargo/circuits/rulebook/Nargo.toml` replaces `circuits/rulebook/Nargo.toml`: +1/-0 lines vs live
- `cargo/circuits/rulebook/src/lib.nr` replaces `circuits/rulebook/src/lib.nr`: +1/-1 lines vs live
- `cargo/circuits/transition/Nargo.toml` replaces `circuits/transition/Nargo.toml`: +1/-0 lines vs live
- `cargo/circuits/transition/src/main.nr` replaces `circuits/transition/src/main.nr`: +7/-7 lines vs live
- `cargo/circuits/transition/Prover.toml` replaces `circuits/transition/Prover.toml`: +6/-5 lines vs live
- `cargo/circuits/nullify/Nargo.toml` replaces `circuits/nullify/Nargo.toml`: +1/-0 lines vs live
- `cargo/circuits/nullify/src/main.nr` replaces `circuits/nullify/src/main.nr`: +6/-6 lines vs live
- `cargo/circuits/nullify/Prover.toml` replaces `circuits/nullify/Prover.toml`: +3/-3 lines vs live
- `cargo/circuits/event-complete/Prover.toml` replaces `circuits/event-complete/Prover.toml`: +4/-4 lines vs live

## Witnessed behavioral delta (task: migrate the circuits commitment hash from pedersen_hash to a Poseidon2 sponge (new shared hash crate over std::hash::poseidon2_permutation); swap all 18 sites across ledger/rulebook/transition/nullify; regenerate the transition/nullify/event-complete Prover.tomls; nargo test green across the workspace, all sample witnesses solve, and the transition gate count collapses from 40,511)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
