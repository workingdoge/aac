# Threshold Brief: cand-0042-bcc-settlement-boundary

Generated: 2026-06-14T05:46:09Z
Status: validated
Intent: Clarify BCC as an agreement certificate with authenticated ECDH and cancellation opening, separating it from private-state settlement proofs and bridge contracts.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/BCC-1.md` replaces `sites/ledger/specs/applications/BCC-1.md`: +237/-79 lines vs live
- `cargo/sites/ledger/specs/applications/README.md` replaces `sites/ledger/specs/applications/README.md`: +0/-0 lines vs live
- `cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json` replaces `sites/ledger/specs/applications/vectors/BCC-DEMO-1.json`: +428/-271 lines vs live
- `cargo/bcc-runtime/package.json` replaces `bcc-runtime/package.json`: +0/-0 lines vs live
- `cargo/bcc-runtime/README.md` replaces `bcc-runtime/README.md`: +19/-5 lines vs live
- `cargo/bcc-runtime/src/index.mjs` replaces `bcc-runtime/src/index.mjs`: +274/-85 lines vs live
- `cargo/bcc-runtime/src/index.d.ts` replaces `bcc-runtime/src/index.d.ts`: +103/-19 lines vs live
- `cargo/bcc-runtime/test/run-tests.mjs` replaces `bcc-runtime/test/run-tests.mjs`: +41/-7 lines vs live

## Witnessed behavioral delta (task: Clarify BCC as an agreement certificate with authenticated ECDH and cancellation opening, separating it from private-state settlement proofs and bridge contracts.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
