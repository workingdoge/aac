# Threshold Brief: cand-0041-bilateral-cancellation-cert

Generated: 2026-06-14T05:04:12Z
Status: validated
Intent: Add BCC/1, a bilateral cancellation certificate primitive: two signed opposite committed records, VNET-style zero-sum verification, optional DH edge material, replay/finality tags, executable vectors, and a JS runtime for building/verifying certificates.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/BCC-1.md` is NEW at `sites/ledger/specs/applications/BCC-1.md`:      135 lines
- `cargo/sites/ledger/specs/applications/README.md` replaces `sites/ledger/specs/applications/README.md`: +1/-0 lines vs live
- `cargo/sites/ledger/specs/applications/vectors/BCC-DEMO-1.json` is NEW at `sites/ledger/specs/applications/vectors/BCC-DEMO-1.json`:      662 lines
- `cargo/bcc-runtime/package.json` is NEW at `bcc-runtime/package.json`:       21 lines
- `cargo/bcc-runtime/README.md` is NEW at `bcc-runtime/README.md`:       22 lines
- `cargo/bcc-runtime/src/index.mjs` is NEW at `bcc-runtime/src/index.mjs`:      386 lines
- `cargo/bcc-runtime/src/index.d.ts` is NEW at `bcc-runtime/src/index.d.ts`:       94 lines
- `cargo/bcc-runtime/test/run-tests.mjs` is NEW at `bcc-runtime/test/run-tests.mjs`:       56 lines

## Witnessed behavioral delta (task: Add BCC/1 bilateral cancellation certificate spec, vectors, and JS runtime: two signed opposite committed records, VNET-style cancellation, optional DH edge material, and replay/finality tag checks.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
