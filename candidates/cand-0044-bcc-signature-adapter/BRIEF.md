# Threshold Brief: cand-0044-bcc-signature-adapter

Generated: 2026-06-14T06:11:19Z
Status: validated
Intent: Add a BCC signature adapter seam with canonical typed-data payloads and make Noir composition explicit through transcript/context commitments rather than in-kernel wallet verification.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/BCC-1.md` replaces `sites/ledger/specs/applications/BCC-1.md`: +65/-4 lines vs live
- `cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json` replaces `sites/ledger/specs/applications/vectors/BCC-DEMO-1.json`: +312/-0 lines vs live
- `cargo/bcc-runtime/package.json` replaces `bcc-runtime/package.json`: +0/-0 lines vs live
- `cargo/bcc-runtime/README.md` replaces `bcc-runtime/README.md`: +22/-0 lines vs live
- `cargo/bcc-runtime/src/index.mjs` replaces `bcc-runtime/src/index.mjs`: +120/-6 lines vs live
- `cargo/bcc-runtime/src/index.d.ts` replaces `bcc-runtime/src/index.d.ts`: +57/-0 lines vs live
- `cargo/bcc-runtime/test/run-tests.mjs` replaces `bcc-runtime/test/run-tests.mjs`: +15/-0 lines vs live
- `cargo/fundraise-runtime/README.md` replaces `fundraise-runtime/README.md`: +4/-0 lines vs live
- `cargo/fundraise-runtime/src/index.mjs` replaces `fundraise-runtime/src/index.mjs`: +5/-1 lines vs live
- `cargo/fundraise-runtime/src/index.d.ts` replaces `fundraise-runtime/src/index.d.ts`: +12/-0 lines vs live
- `cargo/fundraise-runtime/test/run-tests.mjs` replaces `fundraise-runtime/test/run-tests.mjs`: +26/-0 lines vs live

## Witnessed behavioral delta (task: Add a BCC signature adapter seam and keep Noir composition explicit through transcript/context commitments.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
