# Threshold Brief: cand-0028-record-judgment-enforcement

Generated: 2026-06-13T21:02:51Z
Status: validated
Intent: ship tools/record-judgment-check.sh and its 8 record-* fixtures so aac actually enforces premath.record-judgments.v0 — aac enrolls run_suite record-judgments in evaluate-landed but the checker is absent, so the guard is false and the law has been silently skipped every post-land
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `record-judgment-check.sh` is NEW at `tools/record-judgment-check.sh`: 196 lines
- `fixtures/record-meta-telescope-pass-v0.md` is NEW at `sites/premath/fixtures/record-meta-telescope-pass-v0.md`: 14 lines
- `fixtures/record-meta-telescope-fail-v0.md` is NEW at `sites/premath/fixtures/record-meta-telescope-fail-v0.md`: 16 lines
- `fixtures/record-scores-sigma-pass-v0.md` is NEW at `sites/premath/fixtures/record-scores-sigma-pass-v0.md`: 15 lines
- `fixtures/record-scores-sigma-fail-v0.md` is NEW at `sites/premath/fixtures/record-scores-sigma-fail-v0.md`: 15 lines
- `fixtures/record-queue-checking-mode-pass-v0.md` is NEW at `sites/premath/fixtures/record-queue-checking-mode-pass-v0.md`: 14 lines
- `fixtures/record-queue-checking-mode-fail-v0.md` is NEW at `sites/premath/fixtures/record-queue-checking-mode-fail-v0.md`: 14 lines
- `fixtures/record-landing-receipt-pass-v0.md` is NEW at `sites/premath/fixtures/record-landing-receipt-pass-v0.md`: 14 lines
- `fixtures/record-vocab-atom-fail-v0.md` is NEW at `sites/premath/fixtures/record-vocab-atom-fail-v0.md`: 15 lines
- `export-manifest.tsv` replaces `tools/schemas/export-manifest.tsv`: +9/-0 lines vs live

## Witnessed behavioral delta (task: ship tools/record-judgment-check.sh + its 8-fixture ALL_FIXTURES closure (manifest -0/+9) so aac enforces premath.record-judgments.v0 instead of silently skipping it: the manifest still parses with every new entry provided by the LANDING map, the shipped checker + fixtures run --all green against aac's byte-identical statement, the evaluate-landed guard is currently false (checker absent -> member skipped, the footgun) and this candidate lands the checker to flip it true, a corrupted shipped fixture makes --all fail (enforcement real not vacuous), and deltas are additive with the statement not re-added and tools/loop untouched)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
