# Threshold Brief: cand-0021-review-findings

Generated: 2026-06-13T18:47:43Z
Status: validated
Intent: Remediate the post-compaction review findings (P1/P2/P3). P2: NULLIFY/1 must refuse new_value==0 (the empty-slot sentinel TRANSITION/1 reserves) with a negative test; also assert the EVENT-COMPLETE/1 nullifier is nonzero. P3: add a before-first (low_index=0) ACCEPT test so cand-0017's before-first evidence claim is witnessed, plus a correction note on cand-0017. P1: narrow EVENT-COMPLETE/1's obligation-9 claim to an event-scoped one-shot nullifier (H over rulebook+event+parties), NOT the 2/FACT S3 factId-derived nullifier set (cjson-in-circuit unimplemented) -- in the circuit comments and the EVENT-COMPLETE-1.md spec.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/nullify/src/main.nr` replaces `circuits/nullify/src/main.nr`: +30/-0 lines vs live
- `cargo/circuits/event-complete/src/main.nr` replaces `circuits/event-complete/src/main.nr`: +20/-9 lines vs live
- `cargo/sites/ledger/specs/applications/EVENT-COMPLETE-1.md` replaces `sites/ledger/specs/applications/EVENT-COMPLETE-1.md`: +37/-0 lines vs live
- `cargo/candidates/cand-0017-nullify-nonmembership/README.md` replaces `candidates/cand-0017-nullify-nonmembership/README.md`: +9/-0 lines vs live

## Witnessed behavioral delta (task: remediate the post-compaction review: P2 NULLIFY/1 refuses new_value==0 (the TRANSITION/1 empty-slot sentinel) + EVENT-COMPLETE/1 asserts its nullifier nonzero; P3 a before-first (low_index=0) accept test witnesses cand-0017s claim + a correction note; P1 obligation-9 narrowed to an event-scoped nullifier (not the 2/FACT S3 factId derivation) in the circuit and the spec; nargo test+execute green across both changed crates)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
