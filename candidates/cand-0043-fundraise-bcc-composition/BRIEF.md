# Threshold Brief: cand-0043-fundraise-bcc-composition

Generated: 2026-06-14T06:02:05Z
Status: validated
Intent: Bind BCC agreement certificates into FUNDRAISE-CLEARING/1 runtime packets and mint authorization, while keeping bridge settlement as a separate context boundary.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md` replaces `sites/ledger/specs/applications/FUNDRAISE-CLEARING-1.md`: +122/-29 lines vs live
- `cargo/sites/ledger/specs/applications/reference/fundraise_demo.py` replaces `sites/ledger/specs/applications/reference/fundraise_demo.py`: +429/-4 lines vs live
- `cargo/sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json` replaces `sites/ledger/specs/applications/vectors/FUNDRAISE-DEMO-1.json`: +4273/-26 lines vs live
- `cargo/fundraise-runtime/package.json` replaces `fundraise-runtime/package.json`: +0/-0 lines vs live
- `cargo/fundraise-runtime/README.md` replaces `fundraise-runtime/README.md`: +10/-3 lines vs live
- `cargo/fundraise-runtime/src/index.mjs` replaces `fundraise-runtime/src/index.mjs`: +163/-3 lines vs live
- `cargo/fundraise-runtime/src/index.d.ts` replaces `fundraise-runtime/src/index.d.ts`: +35/-0 lines vs live
- `cargo/fundraise-runtime/test/run-tests.mjs` replaces `fundraise-runtime/test/run-tests.mjs`: +36/-0 lines vs live

## Witnessed behavioral delta (task: Bind BCC agreement certificates and bridge settlement context into FUNDRAISE-CLEARING/1 runtime packets and mint authorization.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
