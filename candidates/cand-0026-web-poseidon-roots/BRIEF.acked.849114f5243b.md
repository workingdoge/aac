# Threshold Brief: cand-0026-web-poseidon-roots

Generated: 2026-06-13T20:24:21Z
Status: validated
Intent: Cascade part 2 (cand-0024): update the web components' hard-coded TRANSITION/1 roots from the old pedersen values to the new Poseidon2 values, so /circuit and /registry display the live proof. aac-transition.ts (prev/next account roots, next nullifier root, journal_commitment, fact_fold, ACIR opcodes 775->673) + aac-row.ts (prev/next account, next nullifier) + circuit.mdx (~775->~673 opcodes). astro build green; new values present, no stale pedersen roots remain.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/web/src/components/aac-transition.ts` replaces `web/src/components/aac-transition.ts`: +0/-0 lines vs live
- `cargo/web/src/components/aac-row.ts` replaces `web/src/components/aac-row.ts`: +0/-0 lines vs live
- `cargo/web/src/content/docs/circuit.mdx` replaces `web/src/content/docs/circuit.mdx`: +0/-0 lines vs live

## Witnessed behavioral delta (task: update the web components hard-coded TRANSITION/1 roots from the pre-poseidon values to the cand-0024 Poseidon2 values (aac-transition + aac-row + circuit.mdx opcodes 775->673); astro build green, the new roots bundled, no stale pedersen values anywhere in dist)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
