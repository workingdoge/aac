# Threshold Brief: cand-0010-event-complete-spec

Generated: 2026-06-13T16:35:34Z
Status: validated
Intent: Promote EVENT-COMPLETE/1 from Design Note 0001 sketch to an application-target spec at sites/ledger/specs/applications/: a non-enshrined proof target that J = Phi_R(E,q,evidence,roles) — a typed attested 2/FACT event compiles canonically to a P^n vector zero-account — with the 10-point obligation list, the BVR public ABI, and the completeness-not-truth boundary. Composes with TRANSITION/1; registry MUST NOT require it by default; deployments/policy/admissibility MAY.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/applications/README.md` is NEW at `sites/ledger/specs/applications/README.md`: 18 lines
- `cargo/sites/ledger/specs/applications/EVENT-COMPLETE-1.md` is NEW at `sites/ledger/specs/applications/EVENT-COMPLETE-1.md`: 214 lines

## Witnessed behavioral delta (task: EVENT-COMPLETE/1 application-target spec — declares non-enshrined, states Phi_R + the 10 obligations + the BVR public ABI + the completeness-not-truth boundary; composes with TRANSITION/1; cross-references resolve)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
